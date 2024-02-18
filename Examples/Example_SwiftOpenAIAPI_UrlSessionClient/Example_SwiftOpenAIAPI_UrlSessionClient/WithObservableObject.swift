//
// https://github.com/atacan
// 18.02.24

import Dependencies
import Combine
import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI
import OpenAIUrlSessionDependency

class MyObservableObject: ObservableObject {
    @Dependency(\.openAIUrlSession) var openAIUrlSession
    @Published var text: String = ""
    @Published var yourKey: String = ""
    var cancellables = Set<AnyCancellable>()
    
    init(){
        $yourKey.sink {
//            self.yourKey = UserDefaults.standard.string(forKey: "openapikey") ?? ""
            UserDefaults.standard.setValue($0, forKey: "openapikey")
        }
        .store(in: &cancellables)
    }
    
    @MainActor
    func buttonTapped() {
        print("func buttonTapped")
        Task {
            let output = try! await openAIUrlSession.createChatCompletion(
                .init(
//                    headers: .init(accept: [.init(contentType: .other("text/event-stream"))]),
                    body: .json(
                        .init(
                            messages: [
                                .ChatCompletionRequestSystemMessage(
                                    .init(content: "Only say your name.", role: .system)
                                ),
                                .ChatCompletionRequestUserMessage(.init(content: .case1("Nice to meet you. How are you?"), role: .user))
                            ],
                            model: .init(value2: .gpt_hyphen_3_period_5_hyphen_turbo),
                            stream: false
                        )
                    )
                )
            )
            print(output)
//            for try await o in output.ok.body. {}

            do {
                self.text = try output.ok.body.json.choices.first?.message.content ?? "nil"
            } catch{
                print(error.localizedDescription)
            }
        } // <-Task
    }
}

struct WithObservableObjectView: View {
    @StateObject var vm = withDependencies {
        $0.secrets = .init(openAIKey: {
            let key = UserDefaults.standard.string(forKey: "openapikey")!
            print("openapikey", key)
            return key
        })
    } operation: {
        MyObservableObject()
    }

    
    var body: some View {
        TextField("Your Key", text: $vm.yourKey)
        Button {
            vm.buttonTapped()
        } label: {
            Text("Call")
        } // <-Button
        Text(vm.text)
    }
}

#Preview {
    WithObservableObjectView()
}
