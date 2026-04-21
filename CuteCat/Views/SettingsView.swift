import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PetStore
    @State private var nameText: String = ""
    @State private var selectedVoice: VoiceStyle = .cute
    @StateObject private var speech = SpeechService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundStyle(CozyPalette.moss)
                        TextField("给猫咪起个名字", text: $nameText)
                            .onSubmit {
                                store.renameCat(nameText)
                            }
                    }
                } header: {
                    Text("猫咪名字")
                } footer: {
                    Text("输入后按回车确认")
                }

                Section("声音风格") {
                    ForEach(VoiceStyle.allCases, id: \.self) { style in
                        Button {
                            selectedVoice = style
                            store.setVoiceStyle(style)
                            speech.speak(voicePreviewLine(style), style: style)
                        } label: {
                            HStack(spacing: 10) {
                                Text(style.emoji)
                                    .font(.title3)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(CozyPalette.plum)
                                    Text(style.desc)
                                        .font(.caption2)
                                        .foregroundStyle(CozyPalette.wood)
                                }

                                Spacer()

                                if selectedVoice == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(CozyPalette.moss)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nameText = store.catName
                selectedVoice = store.state.voiceStyle
            }
        }
    }

    private func voicePreviewLine(_ style: VoiceStyle) -> String {
        switch style {
        case .cute: "嘿嘿~人家最喜欢你了~"
        case .baby: "呜呜，抱抱我嘛~"
        case .hyper: "冲冲冲！今天也要元气满满！"
        case .cool: "嗯。随便吧。"
        case .gremlin: "嘻嘻嘻，你上当啦~"
        case .elder: "想当年……老夫可是……"
        case .robot: "系统检测到……一只猫猫……"
        case .demon: "愚蠢的人类……你在召唤我吗……"
        }
    }
}
