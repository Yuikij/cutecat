import Foundation

enum CatFrames {
    // MARK: - Idle (blink, ear twitch, tail wag)
    static let idle: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )         (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )    ~    (
         ( {{WORD}} )
          (  ) _ (  )
          \\~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Happy (bouncy, tail wag, sparkle)
    static let happy: [String] = [
        """
           /\\_____/\\  ✨
          /  ^   ^  \\
         ( ==  w  == )
          )  \\   /  (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
        """
         ✨ /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          ) ~  _  ~ (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  ^   ^  \\  ♪
         ( ==  ω  == )
          )  \\   /  (
         ( {{WORD}} )
          (  ) _ (  )
          \\~~     ~~
        """,
        """
           /\\_____/\\  ♪
          /  ^   ^  \\
         ( ==  w  == )
          )  ~ _ ~  (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Sad (droopy ears, tears)
    static let sad: [String] = [
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )         (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ;   ;  \\
         ( ==  n  == )
          )         (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )    .    (
         ( {{WORD}} )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Hungry (drool, big eyes)
    static let hungry: [String] = [
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  ^  == )
          )    ~    (
         (   🍖...   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  ^  == )
          )  💧     (
         (  🍖...    )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  ω  == )
          )    ~    (
         (    🍖..   )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Sleeping (zzz, peaceful)
    static let sleeping: [String] = [
        """
           /\\_____/\\
          /  -   -  \\   z
         ( ==  w  == )  z
          )         ( z
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\  Z
         ( ==  w  == ) z
          )         (   z
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\    z
         ( ==  ω  == )  z
          )         (  z
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Eating (chewing, food emoji swap, satisfied)
    static let eating: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( == {{FOOD}} == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( == {{FOOD}} == )
          )  ~   ~  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ^   ^  \\
         ( == {{FOOD}} == )
          )  \\   /  (
         (  もぐもぐ   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( == {{FOOD}} == )
          )  ~   ~  (
         (  もぐもぐ   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
         🎉/\\_____/\\🎉
          /  ^   ^  \\
         ( ==  ❤️ == )
          ) ~  _  ~ (
         (   おいしい  )
          (  ) _ (  )
           ~~     ~~
        """,
        """
         🎉/\\_____/\\🎉
          /  ^   ^  \\
         ( ==  ❤️ == )
          )         (
         (   おいしい  )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    static let superFull: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ~  == )
          )         (
         (  太撑了😫  )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ~  == )
          )         (
         (  不吃了🙁  )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ~  == )
          )         (
         (  好饱啊😣  )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    static let vomiting: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )  / _ \\  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( == 🤢 == )
          )  / _ \\  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Bathing (splashy, reluctant)
    static let bath: [String] = [
        """
           /\\_____/\\      o
          /  o   o  \\    o
         ( ==  ^  == ) o
          )~~~~~~~~~(
         (  ~水花~   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\    o
          /  >   <  \\  o
         ( ==  ^  == )   o
          )~~~~~~~~~(
         (  不要洗！  )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\  o
          /  -   -  \\    o
         ( ==  ^  == ) o
          )~~~~~~~~~(
         (  ~哗啦~   )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Sick (thermometer, weak)
    static let sick: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (    💉     )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  n  == )
          )    .    (
         (   难受…   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )         (
         (    💉     )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Discipline (cowering, sulking, plotting revenge)
    static let discipline: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (  {{EMOJI}}       )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  n  == )
          )    .    (
         (  记仇中…  )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  x   x  \\
         ( ==  ^  == )
          )         (
         (  {{EMOJI}}       )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ¬   ¬  \\
         ( ==  ^  == )
          )  哼。    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Playing (chasing, pouncing, tumbling)
    static let playing: [String] = [
        """
           /\\_____/\\
          /  o   o  \\  {{EMOJI}}
         ( ==  w  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              /\\_____/\\
             /  ◉   ◉  \\
         {{EMOJI}} ( ==  w  == )
              )  \\   /  (
             (           )
              (  ) _ (  )
               ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  w  == )  🐾
          )  {{EMOJI}}     (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\  💥
          /  >   <  \\
         ( ==  w  == )
          )     {{EMOJI}}  (
         (  扑！      )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Headpat (purring, melting, nuzzling)
    static let headpat: [String] = [
        """
              ✋
           /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          ) ~     ~ (
         (   purr~   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
             ✋
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  ~   ~  (
         (  咕噜咕噜  )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              ✋
           /\\_____/\\
          /  ^   ^  \\
         ( ==  ω  == )
          ) ~  _  ~ (
         (   purr♡   )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Belly Up (wiggle, vulnerable, happy kicks)
    static let bellyUp: [String] = [
        """
           ~~     ~~
          (  ) _ (  )
         (           )
          )  @   @  (
         ( ==  w  == )
          \\  ^   ^  /
           /\\_____/\\
        """,
        """
           ~~     ~~
          (  ) _ (  )
         (    ~  ~   )
          )  @   @  (
         ( ==  w  == )
          \\  -   -  /
           /\\_____/\\
        """,
        """
          \\~~     ~~/
          (  ) _ (  )
         (   蹬蹬蹬   )
          )  @   @  (
         ( ==  ω  == )
          \\  ^   ^  /
           /\\_____/\\
        """,
    ]

    // MARK: - Shy (blushing, peeking, hiding)
    static let shy: [String] = [
        """
           /\\_____/\\
          /  >   <  \\
         ( == /// == )
          )         (
         (   >///<   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  >   <  \\
         ( == /// == )
          )  ~   ~  (
         (   别看！   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   <  \\
         ( == /// == )
          )    .    (
         (   >///<   )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Thinking (question marks, head tilt)
    static let thinking: [String] = [
        """
           /\\_____/\\   ?
          /  o   o  \\
         ( ==  ^  == )
          )  ?   ?  (
         (    ...    )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   o  \\  ??
         ( ==  ^  == )
          )         (
         (    ..*    )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\  ???
          /  o   -  \\
         ( ==  ^  == )
          )         (
         (    *..    )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Chatting (talking, expressive, musical)
    static let chatting: [String] = [
        """
           /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          )  ~   ~  (
         (    ♪      )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ^   ^  \\  ♪
         ( ==  w  == )
          )         (
         (      ♪    )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  ^   ^  \\
         ( ==  ω  == )
          )  ~   ~  (
         (   ♪  ♫   )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Dead
    static let dead: [String] = [
        """
           /\\_____/\\
          /  x   x  \\
         ( ==  ^  == )
          )         (
         (    🪦     )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Special: Stretching (yawn + stretch)
    static let stretching: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  O  == )
          )         (
         (  哈～欠…   )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )  \\   /  (
         (           )
          (  )   (  )
           ~~  _  ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (  伸懒腰～  )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Special: Zoomies (running around)
    static let zoomies: [String] = [
        """
              /\\_____/\\
             /  ◉   ◉  \\
            ( ==  w  == ) 💨
             ) ~   ~ (
            (         )
             ~~ _ ~~
        """,
        """
        💨   /\\_____/\\
            /  ◉   ◉  \\
           ( ==  w  == )
            ) ~   ~ (
           (         )
            ~~ _ ~~
        """,
        """
           /\\_____/\\  💨💨
          /  ◉   ◉  \\
         ( ==  w  == )
          ) ~   ~ (
         (  发疯！   )
          ~~ _ ~~
        """,
    ]

    // MARK: - Special: Grooming (lick paw, wash face)
    static let grooming: [String] = [
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )    👅   (
         (  舔爪子    )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          ) 👅      (
         (  洗脸中    )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (  整理毛发  )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Special: Excited / Surprised
    static let excited: [String] = [
        """
           /\\_____/\\  ！
          /  ◉   ◉  \\
         ( ==  △  == )
          )  ！！  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
         ！ /\\_____/\\  ！
          /  ◉   ◉  \\
         ( ==  ω  == )
          )         (
         (   ！！！  )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Lookup

    static func frames(for mood: CatMood) -> [String] {
        switch mood {
        case .happy: happy
        case .neutral: idle
        case .sad: sad
        case .hungry: hungry
        case .sick: sick
        case .sleeping: sleeping
        case .dead: dead
        case .eating: eating
        case .playing: playing
        case .bathing: bath
        case .disciplined: discipline
        case .headpat: headpat
        case .bellyUp: bellyUp
        case .shy: shy
        case .thinking: thinking
        case .chatting: chatting
        }
    }

    static func replaceEmoji(in frame: String, emoji: String, word: String? = nil) -> String {
        var result = frame
            .replacingOccurrences(of: "{{FOOD}}", with: emoji)
            .replacingOccurrences(of: "{{EMOJI}}", with: emoji)
        let fill = word ?? ""
        let padded = centerInSlot(fill, slotWidth: 8)
        result = result.replacingOccurrences(of: "{{WORD}}", with: padded)
        return result
    }

    private static func displayWidth(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { acc, sc in
            let v = sc.value
            if (0x2E80...0x9FFF).contains(v) || (0xFF01...0xFF60).contains(v) ||
               (0xFFE0...0xFFE6).contains(v) || (0x3000...0x303F).contains(v) ||
               (0x20000...0x3134F).contains(v) || (0x3400...0x4DBF).contains(v) {
                return acc + 2
            }
            return acc + 1
        }
    }

    private static func centerInSlot(_ text: String, slotWidth: Int) -> String {
        let w = displayWidth(text)
        guard w < slotWidth else { return text }
        let totalPad = slotWidth - w
        let left = totalPad / 2
        let right = totalPad - left
        return String(repeating: " ", count: left) + text + String(repeating: " ", count: right)
    }

    static let idleSpecials: [[String]] = [stretching, zoomies, grooming, excited]

    static func randomIdleSpecial() -> [String]? {
        Int.random(in: 0..<100) < 20 ? idleSpecials.randomElement() : nil
    }
}
