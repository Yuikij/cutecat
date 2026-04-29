import Foundation

enum CatFrames {
    // MARK: - Idle (blink, ear twitch, tail wag)
    static let idle: [String] = [
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
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  -   -  \\
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
          )    ~    (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Happy (bouncy, tail wag)
    static let happy: [String] = [
        """
           /\\_____/\\  *
          /  ^   ^  \\
         ( ==  w  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
         * /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          ) ~  _  ~ (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  ^   ^  \\  ♪
         ( ==  ω  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
        """
           /\\_____/\\  ♪
          /  ^   ^  \\
         ( ==  w  == )
          )  ~ _ ~  (
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ;   ;  \\
         ( ==  n  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )    .    (
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  ^  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  ω  == )
          )    ~    (
         (           )
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

    // MARK: - Eating (chewing, satisfied)
    static let eating: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  w  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  ~   ~  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ^   ^  \\
         ( ==  ω  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  ~   ~  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          ) ~  _  ~ (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          )         (
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ~  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ~  == )
          )         (
         (           )
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
         ( ==  n  == )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\    o
          /  >   <  \\  o
         ( ==  ^  == )   o
          )~~~~~~~~~(
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\  o
          /  -   -  \\    o
         ( ==  ^  == ) o
          )~~~~~~~~~(
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  n  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )         (
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  n  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  x   x  \\
         ( ==  ^  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ¬   ¬  \\
         ( ==  ^  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Playing (chasing, pouncing, tumbling)
    static let playing: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  w  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              /\\_____/\\
             /  ◉   ◉  \\
             ( ==  w  == )
              )  \\   /  (
             (           )
              (  ) _ (  )
               ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  w  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  >   <  \\
         ( ==  w  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Headpat (purring, melting, nuzzling)
    static let headpat: [String] = [
        """
              |
           /\\_____/\\
          /  ^   ^  \\
         ( ==  w  == )
          ) ~     ~ (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
             |
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  ~   ~  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              |
           /\\_____/\\
          /  ^   ^  \\
         ( ==  ω  == )
          ) ~  _  ~ (
         (           )
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
         (    ~  ~   )
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
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  ^   ^  \\  ♪
         ( ==  w  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  ^   ^  \\
         ( ==  ω  == )
          )  ~   ~  (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Away
    static let away: [String] = [
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )  ___    (
         (  /   \\    )
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
         (           )
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
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Special: Zoomies (running around)
    static let zoomies: [String] = [
        """
              /\\_____/\\
             /  ◉   ◉  \\
            ( ==  w  == ) ...
             ) ~   ~ (
            (         )
             ~~ _ ~~
        """,
        """
        ...  /\\_____/\\
            /  ◉   ◉  \\
           ( ==  w  == )
            ) ~   ~ (
           (         )
            ~~ _ ~~
        """,
        """
           /\\_____/\\  ...
          /  ◉   ◉  \\
         ( ==  w  == )
          ) ~   ~ (
         (           )
          ~~ _ ~~
        """,
    ]

    // MARK: - Special: Grooming (lick paw, wash face)
    static let grooming: [String] = [
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )    ~    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )  ~     (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
    ]

    // MARK: - Special: Excited / Surprised
    static let excited: [String] = [
        """
           /\\_____/\\  !
          /  ◉   ◉  \\
         ( ==  △  == )
          )  \\ /   (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
         ! /\\_____/\\  !
          /  ◉   ◉  \\
         ( ==  ω  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Behavior: Waiting (soft eye contact, leaning closer)
    static let waiting: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )    ~    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  ~   ~  (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )    ~    (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Behavior: Hiding (box peek, boundary)
    static let hiding: [String] = [
        """
            ___________
           /  /\\___/\\  \\
          |  /  o o  \\ |
          | ( == ^ == )|
          |  )       ( |
          |____________|
             ~~   ~~
        """,
        """
            ___________
           /           \\
          |   /\\___/\\  |
          |  /  - -  \\ |
          | ( == n == )|
          |___________|
             ~~   ~~
        """,
        """
            ___________
           /  /\\___/\\  \\
          |  /  o <  \\ |
          | ( == ^ == )|
          |  )       ( |
          |____________|
             ~~   ~~/
        """,
    ]

    // MARK: - Behavior: Searching Food (sniffing, bowl check)
    static let searchingFood: [String] = [
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  ^  == )
          )   . .   (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              /\\_____/\\
             /  ◉   ◉  \\
             ( ==  ^  == )
             )   ...   (
            (           )
             (  ) _ (  )
              ~~     ~~
        """,
        """
           /\\_____/\\
          /  ◉   ◉  \\  !
         ( ==  ω  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Behavior: Napping (curled, breathing)
    static let napping: [String] = [
        """
              z
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  _____  (
         (  /     \\  )
           ~~     ~~
        """,
        """
             Z  z
           /\\_____/\\
          /  -   -  \\
         ( ==  ω  == )
          )  _____  (
         (  /     \\  )
           ~~     ~~
        """,
        """
                z
           /\\_____/\\
          /  -   -  \\
         ( ==  w  == )
          )  _____  (
         (  /     \\  )
           ~~     ~~
        """,
    ]

    // MARK: - Behavior: Investigating (sniff, inspect)
    static let investigating: [String] = [
        """
           /\\_____/\\   ?
          /  o   o  \\
         ( ==  ^  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   -  \\  ??
         ( ==  ^  == )
          )  .      (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  ◉   ◉  \\
         ( ==  △  == )
          )  \\ /   (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Behavior: Guarding Belly (defensive, trust boundary)
    static let guardingBelly: [String] = [
        """
           /\\_____/\\
          /  ¬   ¬  \\
         ( ==  ^  == )
          )  _ _   (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  n  == )
          )   _ _  (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\
          /  -   -  \\
         ( ==  ^  == )
          )  _ _   (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Behavior: Writing Diary (private inner life)
    static let writingDiary: [String] = [
        """
           /\\_____/\\
          /  o   o  \\
         ( ==  ^  == )
          )   /    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   o  \\
         ( ==  ^  == )
          )  //    (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\  ...
          /  o   -  \\
         ( ==  ^  == )
          )   /    (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Behavior: Showing Off (performing, playful pride)
    static let showingOff: [String] = [
        """
         * /\\_____/\\ *
          /  ^   ^  \\
         ( ==  w  == )
          )  \\   /  (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\   *
          /  ^   ^  \\
         ( ==  ω  == )
          ) ~  _  ~ (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
         * /\\_____/\\
          /  ◉   ◉  \\
         ( ==  w  == )
          )  \\ /   (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Behavior: Sulking (turned away, moody but reachable)
    static let sulking: [String] = [
        """
           /\\_____/\\
          /  ¬   ¬  \\
         ( ==  n  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              /\\_____/\\
             /  -   -  \\
            ( ==  n  == )
             )    .    (
            (           )
             (  ) _ (  )
              ~~     ~~
        """,
        """
           /\\_____/\\
          /  o   ¬  \\
         ( ==  n  == )
          )    ...  (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
    ]

    // MARK: - Behavior: Plotting (tiny schemes)
    static let plotting: [String] = [
        """
           /\\_____/\\  ...
          /  ¬   ¬  \\
         ( ==  w  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
           /\\_____/\\
          /  -   ¬  \\
         ( ==  w  == )
          )    .    (
         (           )
          (  ) _ (  )
           ~~     ~~/
        """,
        """
           /\\_____/\\  !
          /  ◉   ◉  \\
         ( ==  w  == )
          )  \\ /   (
         (           )
          (  ) _ (  )
          \\~~     ~~
        """,
    ]

    // MARK: - Behavior: Leaving (edge state, emotional stakes)
    static let leaving: [String] = [
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )         (
         (           )
          (  ) _ (  )
           ~~     ~~
        """,
        """
              /\\_____/\\
             /  ;   ;  \\
            ( ==  n  == )
             )       (
            (           )
             (  ) _ (  )
              ~~     ~~
        """,
        """
           /\\_____/\\
          /  T   T  \\
         ( ==  ^  == )
          )    .    (
         (           )
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
        case .away: away
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

    static func frames(for mood: CatMood, behavior: CatBehaviorKind?) -> [String] {
        guard let behavior, behavior.displayMood == mood else {
            return frames(for: mood)
        }

        switch behavior {
        case .idle:
            return frames(for: mood)
        case .waiting:
            return waiting
        case .hiding:
            return hiding
        case .searchingFood:
            return searchingFood
        case .napping:
            return napping
        case .grooming:
            return grooming
        case .investigating:
            return investigating
        case .guardingBelly:
            return guardingBelly
        case .writingDiary:
            return writingDiary
        case .showingOff:
            return showingOff
        case .sulking:
            return sulking
        case .plotting:
            return plotting
        case .leaving:
            return leaving
        }
    }

    static func replaceEmoji(in frame: String, emoji: String, word: String? = nil) -> String {
        _ = emoji
        _ = word
        return frame
    }

    static let idleSpecials: [[String]] = [stretching, zoomies, grooming, excited]

    static func randomIdleSpecial() -> [String]? {
        Int.random(in: 0..<100) < 20 ? idleSpecials.randomElement() : nil
    }
}
