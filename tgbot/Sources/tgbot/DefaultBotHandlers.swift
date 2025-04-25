//
//  DefaultBotHandlers.swift
//  tgbot
//
//  Created by Emir Byashimov on 02.04.2025.
//

import Foundation
import SwiftTelegramSdk
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class DefaultBotHandlers {
    
    static var awaitingFileUsers: Set<Int64> = []
    
    static func addHandlers(bot: TGBot) async {
        print("Adding bot handlers...")
        await messageHandler(bot: bot)
        await commandPingHandler(bot: bot)
        await commandShowButtonsHandler(bot: bot)
        await buttonsActionHandler(bot: bot)
        await commandUploadFileHandler(bot: bot)
        await documentHandler(bot: bot)
    }
    
    private static func commandUploadFileHandler(bot: TGBot) async {
        print("Setting up /upload_file command handler...")
        await bot.dispatcher.add(TGCommandHandler(commands: ["/upload_file"]) { update in
            guard let userId = update.message?.from?.id else {
                print("User ID not found for /upload_file")
                return
            }
            
            awaitingFileUsers.insert(userId)
            
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Отправьте файл для загрузки.")
            do {
                try await bot.sendMessage(params: params)
                print("Message sent to user \(userId): 'Отправьте файл для загрузки.'")
            } catch {
                print("Error sending message to user \(userId): \(error.localizedDescription)")
            }
        })
    }
    
    private static func documentHandler(bot: TGBot) async {
        print("Setting up document handler...")
        await bot.dispatcher.add(TGMessageHandler(filters: .document) { update in
            guard let userId = update.message?.from?.id, awaitingFileUsers.contains(userId),
                  let document = update.message?.document else {
                print("No valid document received or user not awaiting file.")
                return
            }
            
            awaitingFileUsers.remove(userId)
            
            let fileId = document.fileId
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Файл получен! Идет обработка...")
            do {
                try await bot.sendMessage(params: params)
                print("Message sent to user \(userId): 'Файл получен! Идет обработка...'")
            } catch {
                print("Error sending message to user \(userId): \(error.localizedDescription)")
            }
            
            await processFile(fileId: fileId, bot: bot, chatId: userId)
        })
    }
    
    private static func processFile(fileId: String, bot: TGBot, chatId: Int64) async {
        print("Processing file with ID: \(fileId)...")
        do {
            let fileParams = TGGetFileParams(fileId: fileId)
            let file = try await bot.getFile(params: fileParams)
            
            guard let filePath = file.filePath else {
                throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Файл не найден"])
            }
            
            let telegramFileURL = "https://api.telegram.org/file/bot\(ProcessInfo.processInfo.environment["TELEGRAM_BOT_API"] ?? "")/\(filePath)"
            print("Downloading file from URL: \(telegramFileURL)")
            let savePath = "/root/LeonardEulerBot/tgbot/documents/\(UUID().uuidString).pdf"
            
            try await downloadFile(from: telegramFileURL, to: savePath)
            print("File downloaded and saved to: \(savePath)")
            
            let successMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Файл сохранен: \(savePath)")
            try await bot.sendMessage(params: successMessage)
            
            do {
                let fileData = try Data(contentsOf: URL(fileURLWithPath: savePath))
                print("File data read successfully.")
                
                // Создаем TGInputFile с данными, именем файла и MIME-типом
                let inputFile = TGInputFile(filename: "respondFile.pdf", data: fileData, mimeType: "application/pdf")
                
                // Создаем TGFileInfo с этим файлом
                let fileInfo = TGFileInfo.file(inputFile)
                
                // Отправка файла через Telegram API
                let params = TGSendDocumentParams(
                    chatId: .chat(chatId),
                    document: fileInfo,  // Передаем TGFileInfo.file
                    caption: "Файл успешно загружен и отправлен"
                )
                
                // Отправляем документ
                try await bot.sendDocument(params: params)
                print("File successfully sent to user \(chatId).")
            } catch {
                print("Ошибка при чтении файла или отправке: \(error.localizedDescription)")
                let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка отправки файла.")
                try? await bot.sendMessage(params: errorMessage)
            }
            
        } catch {
            print("Ошибка при обработке файла: \(error.localizedDescription)")
            let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка обработки файла.")
            try? await bot.sendMessage(params: errorMessage)
        }
    }
    
    private static func downloadFile(from url: String, to path: String) async throws {
        print("Downloading file from URL: \(url) to path: \(path)...")
        guard let fileURL = URL(string: url) else {
            throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Некорректный URL"])
        }

        let request = URLRequest(url: fileURL)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Ошибка загрузки файла"])
            }

            try data.write(to: URL(fileURLWithPath: path))
            print("File successfully downloaded to: \(path)")
        } catch {
            print("Error downloading file: \(error.localizedDescription)")
            throw error
        }
    }

    private static func messageHandler(bot: TGBot) async {
        print("Setting up message handler...")
        await bot.dispatcher.add(TGMessageHandler(filters: (.all && !.command.names(["/ping", "/show_buttons"]))) { update in
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "Success")
            try await bot.sendMessage(params: params)
            print("Message sent: 'Success'")
        })
    }
    
    private static func commandPingHandler(bot: TGBot) async {
        print("Setting up /ping command handler...")
        await bot.dispatcher.add(TGCommandHandler(commands: ["/ping"]) { update in
            try await update.message?.reply(text: "pong", bot: bot)
            print("/ping command received, 'pong' sent.")
        })
    }
    
    private static func commandShowButtonsHandler(bot: TGBot) async {
        print("Setting up /show_buttons command handler...")
        await bot.dispatcher.add(TGCommandHandler(commands: ["/show_buttons"]) { update in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Button 1", callbackData: "press 1"), .init(text: "Button 2", callbackData: "press 2")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Keyboard active",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
            print("/show_buttons command received, buttons sent to user \(userId).")
        })
    }
    
    private static func buttonsActionHandler(bot: TGBot) async {
        print("Setting up buttons action handler...")
        await bot.dispatcher.add(TGCallbackQueryHandler(pattern: "press 1") { update in
            print("Button 1 pressed.")
            guard let userId = update.callbackQuery?.from.id else { fatalError("user id not found") }
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
            try await bot.sendMessage(params: .init(chatId: .chat(userId), text: "press 1"))
        })
        
        await bot.dispatcher.add(TGCallbackQueryHandler(pattern: "press 2") { update in
            print("Button 2 pressed.")
            guard let userId = update.callbackQuery?.from.id else { fatalError("user id not found") }
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
            try await bot.sendMessage(params: .init(chatId: .chat(userId), text: "press 2"))
        })
    }
}
