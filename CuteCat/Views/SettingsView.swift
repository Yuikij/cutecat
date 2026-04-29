import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PetStore
    @State private var nameText: String = ""

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
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nameText = store.catName
            }
        }
    }
}
