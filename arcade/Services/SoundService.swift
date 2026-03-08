import AppKit

enum SoundService {
    private static let mutedKey = "soundMuted"

    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: mutedKey) }
        set { UserDefaults.standard.set(newValue, forKey: mutedKey) }
    }

    // MARK: - Semantic Sounds

    static func confirm() { play("Tink") }
    static func select() { play("Pop") }
    static func generate() { play("Submarine") }
    static func complete() { play("Glass") }
    static func error() { play("Basso") }
    static func bookmark() { play("Bottle") }
    static func fidget() { play("Pop") }
    static func keySaved() { play("Purr") }

    static func paletteOpen() { play("Pop", volume: 0.4) }

    // MARK: - Playback

    private static func play(_ name: String, volume: Float = 1.0) {
        guard !isMuted else { return }
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = volume
        sound.play()
    }
}
