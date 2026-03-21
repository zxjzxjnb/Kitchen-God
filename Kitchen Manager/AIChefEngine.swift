import SwiftUI

enum AIChefEngine {
    
    // MARK: - API Response Models
    private struct IngredientPayload: Codable {
        let name: String
        let quantity: Double
        let unit: String
    }

    private struct APIRecipeResponse: Codable {
        let dish: String
        let tips: String
        let ingredients: [IngredientPayload]
    }
    
    private struct APISuggestionsResponse: Codable {
        let suggestions: [SuggestionPayload]
        
        struct SuggestionPayload: Codable {
            let dish: String
            let reason: String
            let ingredients: [IngredientPayload]
        }
    }
    
    // MARK: - Core Networking
    
    private static func callOpenAI(
        systemPrompt: String,
        userPrompt: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "AIChefEngine", code: 401, userInfo: [NSLocalizedDescriptionKey: "请先在设置里配置灶王爷 API Key。"])
        }
        
        // Ensure baseURL points to chat/completions
        var endpoint = baseURL
        if !endpoint.hasSuffix("/chat/completions") {
            if endpoint.hasSuffix("/") {
                endpoint += "chat/completions"
            } else {
                endpoint += "/chat/completions"
            }
        }
        
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "AIChefEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的 Base URL，请检查设置。"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpRes = response as? HTTPURLResponse else {
            throw NSError(domain: "AIChefEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "网络响应异常。"])
        }
        
        if !(200...299).contains(httpRes.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知 API 错误"
            throw NSError(domain: "AIChefEngine", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API 错误 (\(httpRes.statusCode)): \(errorMsg)"])
        }
        
        return data
    }

    private static func assistantContent(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]

        if let content = message?["content"] as? String {
            return stripCodeFenceIfNeeded(content)
        }

        if let contentParts = message?["content"] as? [[String: Any]] {
            let joined = contentParts.compactMap { $0["text"] as? String }.joined()
            if !joined.isEmpty {
                return stripCodeFenceIfNeeded(joined)
            }
        }

        throw NSError(domain: "AIChefEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "AI 返回的数据格式无法解析。"])
    }

    private static func stripCodeFenceIfNeeded(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        let lines = trimmed.components(separatedBy: .newlines)
        let cleaned = lines
            .dropFirst()
            .reversed()
            .dropFirst()
            .reversed()
            .joined(separator: "\n")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Public API

    static func recipe(for dish: String, inventory: [InventoryItem], store: KitchenStore) async throws -> AIRecipeResult {
        let systemPrompt = """
        你是一个专业的米其林大厨，请为用户提供的菜名生成一份家常做法食谱。
        你必须以严格的 JSON 格式输出，且根节点必须是一个 Object。
        不要输出 Markdown，不要使用“适量”，数量必须是数字。
        JSON 格式要求如下：
        {
          "dish": "标准化的菜品名称",
          "tips": "一句话烹饪核心技巧或步骤（少于30字）",
          "ingredients": [
            { "name": "食材1名称", "quantity": 1.5, "unit": "个/克/勺等" }
          ]
        }
        """
        
        let data = try await callOpenAI(
            systemPrompt: systemPrompt,
            userPrompt: "请提供【\(dish)】的食谱。",
            apiKey: store.aiApiKey,
            baseURL: store.aiBaseURL,
            model: store.aiModel
        )
        
        let content = try assistantContent(from: data)
        guard let contentData = content.data(using: .utf8) else {
            throw NSError(domain: "AIChefEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "AI 返回的数据格式无法解析。"])
        }
        
        let apiResponse = try JSONDecoder().decode(APIRecipeResponse.self, from: contentData)
        
        let mappedIngredients = apiResponse.ingredients.map { payload in
            ingredientStatus(name: payload.name, quantity: payload.quantity, unit: payload.unit, inventory: inventory)
        }
        
        return AIRecipeResult(dish: apiResponse.dish, ingredients: mappedIngredients, tips: apiResponse.tips)
    }

    static func suggestions(from inventory: [InventoryItem], store: KitchenStore) async throws -> [AISuggestion] {
        let inventoryContext = inventory.map { "\($0.name)(\($0.quantity)\($0.unit))" }.joined(separator: ", ")
        
        let systemPrompt = """
        你是家庭厨房助手“灶王爷”。请根据用户提供的现有食材库存，推荐 3 到 4 道菜品。
        可以优先使用易过期的食材。推荐的菜品可以需要少量额外购买的食材，但主要应基于现有食材。
        对每道菜都要列出做这道菜的核心食材，数量必须是数字，不要写“适量”，不要输出 Markdown。
        必须以严格的 JSON 格式输出，且根节点必须是一个 Object。
        JSON 格式要求：
        {
          "suggestions": [
            {
              "dish": "菜品名称",
              "reason": "推荐理由（结合库存情况，少于20字）",
              "ingredients": [
                { "name": "食材1名称", "quantity": 1.5, "unit": "个/克/勺等" }
              ]
            }
          ]
        }
        """
        
        let data = try await callOpenAI(
            systemPrompt: systemPrompt,
            userPrompt: "当前库存：\(inventoryContext.isEmpty ? "空" : inventoryContext)。请推荐今天的菜单。",
            apiKey: store.aiApiKey,
            baseURL: store.aiBaseURL,
            model: store.aiModel
        )
        
        let content = try assistantContent(from: data)
        guard let contentData = content.data(using: .utf8) else {
            throw NSError(domain: "AIChefEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "AI 返回的数据格式无法解析。"])
        }
        
        let apiResponse = try JSONDecoder().decode(APISuggestionsResponse.self, from: contentData)

        return apiResponse.suggestions
            .map { suggestion in
                AISuggestion(
                    dish: suggestion.dish,
                    ingredients: suggestion.ingredients.map { payload in
                        ingredientStatus(
                            name: payload.name,
                            quantity: payload.quantity,
                            unit: payload.unit,
                            inventory: inventory
                        )
                    },
                    reason: suggestion.reason
                )
            }
            .sorted { lhs, rhs in
                if lhs.canCookNow != rhs.canCookNow {
                    return lhs.canCookNow && !rhs.canCookNow
                }
                if lhs.missingIngredients.count != rhs.missingIngredients.count {
                    return lhs.missingIngredients.count < rhs.missingIngredients.count
                }
                return lhs.dish < rhs.dish
            }
    }

    private static func ingredientStatus(name: String, quantity: Double, unit: String, inventory: [InventoryItem]) -> RecipeIngredient {
        if let item = inventory.first(where: { KitchenData.isLikelySameIngredient($0.name, name) }) {
            let currentValue = Double(item.quantity) ?? 0
            let unitsMatch = item.unit == unit
            let shortageQuantity = unitsMatch ? max(quantity - currentValue, 0) : quantity
            return RecipeIngredient(
                name: name,
                quantity: quantity,
                unit: unit,
                currentQuantity: "\(item.quantity)\(item.unit)",
                shortageQuantity: shortageQuantity,
                needToBuy: shortageQuantity > 0
            )
        }

        return RecipeIngredient(
            name: name,
            quantity: quantity,
            unit: unit,
            currentQuantity: "无",
            shortageQuantity: quantity,
            needToBuy: true
        )
    }
}
