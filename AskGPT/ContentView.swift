//
//  ContentView.swift
//  AskGPT
//
//  Created by katsumasa.watanabe on 2024/11/07.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    @State private var question = ""
    @State private var response = ""
    var body: some View {
        VStack {
            TextField("", text: $question)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button("ASK") {
                viewModel.fetch()
            }
            Text(viewModel.content)
                .padding()
        }
        .padding()
    }
}

class ViewModel: ObservableObject {
    @Published var content: String = ""

    let openAPIRequester = OpenAPIRequester()
    let weatherAPIRequester = WeatherAPIRequester()

    @MainActor
    func fetch() {
        Task {
            do {
                content = try await weatherAPIRequester.fetch(latitude: "33.44", longitude: "-94.04")
            } catch {
                let error = error as? APIClientError ?? APIClientError.unknown
                print(error.title)
            }
        }
    }
}

#Preview {
    ContentView()
}

struct OpenAPIRequester {

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Float

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct APIResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message

            struct Message: Decodable {
                let content: String
            }
        }
    }

    func postGPT(_ content: String) async throws -> String {
        let apiKey = "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"
        var request = URLRequest(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!
        )
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                model: "gpt-3.5-turbo",
                messages: [RequestBody.Message(role: "user", content: content)],
                temperature: 1.0
            )
        )
        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            throw APIClientError.networkError
        }
        guard let response = try? JSONDecoder().decode(APIResponse.self, from: data) else {
            throw APIClientError.decodeError
        }
        guard let content = response.choices.first?.message.content else {
            throw APIClientError.invalidResponse
        }
        return content
    }
}

enum APIClientError: Error {
    case networkError
    case invalidResponse
    case decodeError
    case unknown

    var title: String {
        switch self {
        case .decodeError:
            return "DECODE"
        case .invalidResponse:
            return "INVALID"
        case .networkError:
            return "NETWORK"
        case .unknown:
            return "Unknown"
        }
    }
}

struct WeatherAPIRequester {

    private struct APIResponse: Decodable {
        let current: Current

        struct Current: Decodable {
            let weather: [Weather]

            struct Weather: Decodable {
                let main: String
            }
        }
    }

    func fetch(latitude: String, longitude: String) async throws -> String {
        let url = URL(string: "https://api.openweathermap.org/data/3.0/onecall?lat=\(latitude)&lon=\(longitude)&appid=\(Key.whetherKey)")!
        guard let (data, response) = try? await URLSession.shared.data(from: url) else {
            throw APIClientError.networkError
        }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            let response = response as! HTTPURLResponse
            print(response.statusCode)
            throw APIClientError.invalidResponse
        }
        guard let result = try? JSONDecoder().decode(APIResponse.self, from: data) else {
            throw APIClientError.decodeError
        }
        return result.current.weather[0].main
    }
}

private struct Key {
    static let openAIKey = "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"

    static let whetherKey = "236d7abc88ccc85da67431dd57114e19"
}
