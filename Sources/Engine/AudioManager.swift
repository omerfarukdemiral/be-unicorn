import Foundation
import AVFoundation

/// Dosya tabanlı UI sesi + arka plan müziği yöneticisi.
///
/// Bundle'a gömülü kısa CC0 SFX dosyaları (`sfx_*.wav`) ve ambient bir döngü (`music_loop.m4a`)
/// kullanır. Her efekt için 2 oynatıcılı bir havuz var; ardışık çağrılar birbirini kesmesin diye
/// dönüşümlü çalınır. Ses kategorisi `.ambient` — sessiz anahtarına saygı, başka müziklerle karışır.
///
/// API kontratı:
/// * `configure()` — uygulama açılırken çağrılır (UnicornApp).
/// * `pause()`/`resume()` — scene lifecycle (ContentView).
/// * `Feedback.play()` (Haptics.swift) üzerinden semantik çağrılar: `tap/select/decision/success/close/celebrate/warning/failure`.
/// * `setEnabled(_:)`/`toggle()`/`isEnabled` — UI ses açma/kapama.
/// * `setMusicEnabled(_:)`/`isMusicEnabled` — müzik aç/kapa.
///
/// Bundle'da SFX dosyası bulunamazsa o çağrı sessizce yutulur (sentetik fallback YOK).
@MainActor
final class AudioManager {
    static let shared = AudioManager()

    // MARK: - UserDefaults anahtarları (kalıcı ayar)

    private let soundKey = "unicorn.soundEnabled"
    private let musicKey = "unicorn.musicEnabled"

    /// UI sesinin açık/kapalı durumu (UserDefaults'ta kalıcı).
    private(set) var isEnabled: Bool

    /// Arka plan müziğinin açık/kapalı durumu (UserDefaults'ta kalıcı).
    private(set) var isMusicEnabled: Bool

    // MARK: - Oynatıcılar

    /// Her SFX için 2 önceden yüklenmiş AVAudioPlayer (round-robin çakışmasız çalma).
    private var sfxPlayers: [SFX: [AVAudioPlayer]] = [:]
    private var sfxCursor: [SFX: Int] = [:]

    /// Arka plan müziği oynatıcısı (sonsuz döngü).
    private var musicPlayer: AVAudioPlayer?

    /// Müzik çalmaya hazır mı (configure başarılı + dosya bulundu)?
    private var musicReady = false

    /// Uygulama foreground'da mı (müziği duraklat/sürdür kontrolü için).
    private var isForeground = true

    private var configured = false

    // MARK: - SFX enum — SFX dosya isimleriyle eşleşir

    /// AudioManager'ın çalabildiği semantik efektler.
    /// Bundle'daki dosya adı `sfx_<rawValue>.wav` ile eşleşir.
    enum SFX: String, CaseIterable {
        case tap, select, decision, success, close, celebrate, warning, failure
    }

    // MARK: - Init

    private init() {
        // Varsayılan: ses açık, müzik açık (ilk kurulumda).
        let defs = UserDefaults.standard
        isEnabled      = defs.object(forKey: soundKey) == nil ? true : defs.bool(forKey: soundKey)
        isMusicEnabled = defs.object(forKey: musicKey) == nil ? true : defs.bool(forKey: musicKey)
    }

    // MARK: - Kurulum / lifecycle

    /// Uygulama başında bir kez: session ayarı + tüm SFX/müzik dosyalarını önceden yükle.
    /// Hatalar sessizce yutulur (ses kritik değil; dosya yoksa sessiz kalır).
    func configure() {
        guard !configured else { return }
        configured = true

        // .ambient: sessiz anahtarına saygı duy, başka müziklerle karışsın.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Session başarısız — yine de oynatıcıları kurmayı dene.
        }

        // Tüm SFX dosyalarını önceden yükle (her biri için 2 oynatıcı; round-robin).
        for fx in SFX.allCases {
            sfxPlayers[fx] = preloadPlayers(named: "sfx_\(fx.rawValue)", count: 2, volume: defaultVolume(for: fx))
            sfxCursor[fx] = 0
        }

        // Müzik oynatıcısını hazırla (loop sonsuz, düşük volume).
        if let url = audioURL(named: "music_loop") {
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = -1
                p.volume = 0.32           // ambient hissi için düşük volume
                p.prepareToPlay()
                musicPlayer = p
                musicReady = true
            } catch {
                musicReady = false
            }
        }

        // İlk açılışta müzik açıksa başlat.
        if isMusicEnabled { startMusicIfNeeded() }
    }

    /// Arka plana geçince müziği duraklat (pil/CPU). Foreground'da resume.
    func pause() {
        isForeground = false
        musicPlayer?.pause()
        // SFX'ler kısa; arka planda kalmaları sorun değil.
    }

    func resume() {
        isForeground = true
        if isMusicEnabled, musicReady { startMusicIfNeeded() }
    }

    // MARK: - Toggle (UI tarafından çağrılır)

    /// UI sesini aç/kapa (kalıcı).
    func setEnabled(_ on: Bool) {
        isEnabled = on
        UserDefaults.standard.set(on, forKey: soundKey)
        if on { play(.tap) }   // küçük onay dokunuşu
    }

    @discardableResult
    func toggle() -> Bool {
        setEnabled(!isEnabled)
        // Aynı tab bar düğmesi müziği de eşzamanlı aç/kapasın (tek toggle UX).
        setMusicEnabled(isEnabled)
        return isEnabled
    }

    /// Müziği aç/kapa (kalıcı).
    func setMusicEnabled(_ on: Bool) {
        isMusicEnabled = on
        UserDefaults.standard.set(on, forKey: musicKey)
        if on {
            startMusicIfNeeded()
        } else {
            musicPlayer?.pause()
        }
    }

    @discardableResult
    func toggleMusic() -> Bool {
        setMusicEnabled(!isMusicEnabled)
        return isMusicEnabled
    }

    // MARK: - Anlamsal efektler (Haptics.SFX çağırır)

    /// İşe alım / eşya alımı / hafif onay.
    func tap()       { play(.tap) }
    /// Tab/seçim değişimi — çok kısa nötr tık.
    func select()    { play(.select) }
    /// Karar kartı geldi — dikkat çeken nota.
    func decision()  { play(.decision) }
    /// Günlük hedef / sprint başarısı.
    func success()   { play(.success) }
    /// Çeyrek/büyük kapanış.
    func close()     { play(.close) }
    /// Funding / sezon finali / win — görkemli.
    func celebrate() { play(.celebrate) }
    /// Kritik uyarı.
    func warning()   { play(.warning) }
    /// İflas / başarısız sprint.
    func failure()   { play(.failure) }

    // MARK: - Çalma çekirdeği

    /// Round-robin oynatıcı havuzundan birini çal. Toggle kapalıysa veya
    /// dosya bulunamadıysa sessizce çıkar.
    private func play(_ fx: SFX) {
        guard isEnabled else { return }
        guard let pool = sfxPlayers[fx], !pool.isEmpty else { return }
        let cursor = sfxCursor[fx] ?? 0
        let player = pool[cursor % pool.count]
        sfxCursor[fx] = (cursor + 1) % pool.count
        // Aynı player tekrar çalıyorsa baştan başlasın (kısa SFX'lerde "kesme" hissi tutarlı).
        if player.isPlaying { player.currentTime = 0 }
        player.play()
    }

    /// Müziği çalmaya başla (henüz çalmıyorsa). Foreground değilse beklesin.
    private func startMusicIfNeeded() {
        guard musicReady, isMusicEnabled, isForeground, let p = musicPlayer else { return }
        if !p.isPlaying { p.play() }
    }

    // MARK: - Yardımcılar

    /// Bir SFX için varsayılan volume (her efekt kendi karakterine göre dengelenir).
    private func defaultVolume(for fx: SFX) -> Float {
        switch fx {
        case .tap:       return 0.55   // hafif tık — bastırıcı olmasın
        case .select:    return 0.45
        case .decision:  return 0.75
        case .success:   return 0.80
        case .close:     return 0.75
        case .celebrate: return 0.85   // ödül anı — biraz daha öne çık
        case .warning:   return 0.75
        case .failure:   return 0.80
        }
    }

    /// `name` adlı ses dosyası için `count` adet önceden yüklenmiş AVAudioPlayer oluştur.
    /// Bulunamayan/yüklenemeyen dosyalar boş havuzla döner (çalma sessizce yutulur).
    private func preloadPlayers(named name: String, count: Int, volume: Float) -> [AVAudioPlayer] {
        guard let url = audioURL(named: name) else { return [] }
        var players: [AVAudioPlayer] = []
        players.reserveCapacity(count)
        for _ in 0..<count {
            if let p = try? AVAudioPlayer(contentsOf: url) {
                p.volume = volume
                p.prepareToPlay()
                players.append(p)
            }
        }
        return players
    }

    /// Bundle'dan bilinen ses uzantıları için dosya URL'si bul.
    private func audioURL(named name: String) -> URL? {
        for ext in ["wav", "m4a", "mp3", "caf", "aac"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
