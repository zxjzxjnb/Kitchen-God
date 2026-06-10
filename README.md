# Kitchen Manager

Kitchen Manager is a SwiftUI iOS app for managing a household kitchen workflow: deciding what to cook, tracking what is already in stock, planning shopping trips, and understanding monthly kitchen spending.

The app includes an AI cooking assistant named Zao Wangye. It can generate recipes from a dish name, suggest meals based on current inventory, identify missing ingredients, and sync those ingredients into the shopping list.

## Features

- **Home dashboard**: summarizes today's meals, pending shopping items, budget status, hydration progress, and inventory alerts.
- **Meal planning**: plans breakfast, lunch, dinner, and drinks across a weekly schedule.
- **AI recipe assistant**: generates recipes, recommends dishes from available ingredients, and marks ingredients that need to be purchased.
- **Shopping list**: tracks items, quantities, categories, shopping days, estimated costs, and completed purchases.
- **Inventory management**: stores ingredient quantities, units, categories, unit prices, freshness windows, expiration dates, and low-stock thresholds.
- **Alert system**: detects expired items, soon-to-expire items, stale ingredients, and low-stock inventory.
- **Budget tracking**: records monthly budget, purchase transactions, waste costs, and shopping estimates.
- **Local persistence**: saves app state as JSON in the user's Documents directory.

## Tech Stack

- **Language**: Swift
- **UI**: SwiftUI
- **State management**: `@Observable` with environment injection
- **Core store**: `KitchenStore`
- **AI integration**: `AIChefEngine`, using an OpenAI Chat Completions-compatible API
- **Inventory alerts**: `AlertEngine`
- **Local data rules**: `KitchenData` for ingredient categories, unit guesses, name normalization, and estimated prices
- **Secret storage**: API keys are stored in the system Keychain instead of the app's JSON state file

## Architecture

The app centers on `KitchenStore`, which coordinates the main product flows:

- Loading and saving inventory, shopping, meal planning, budget, hydration, and AI settings.
- Syncing missing recipe ingredients into the shopping list.
- Merging checked shopping items into inventory after checkout.
- Recording purchase transactions and updating the monthly kitchen budget.
- Reversing inventory and budget effects when purchase records are edited or deleted.
- Computing dashboard metrics such as alert count, pending shopping cost, and projected budget remaining.

`AlertEngine` is kept separate from the store so expiration, freshness, and low-stock rules are easier to test and maintain. `AIChefEngine` handles the network request and JSON parsing for recipe generation and inventory-based suggestions.

## Project Structure

```text
Kitchen Manager/
├── README.md
├── Kitchen Manager.xcodeproj/
└── Kitchen Manager/
    ├── Kitchen_ManagerApp.swift
    ├── ContentView.swift
    ├── HomePage.swift
    ├── MealPlanPage.swift
    ├── ShoppingPage.swift
    ├── InventoryPage.swift
    ├── BudgetPage.swift
    ├── KitchenStore.swift
    ├── AIChefEngine.swift
    ├── AlertEngine.swift
    ├── Models.swift
    ├── KitchenData.swift
    └── Assets.xcassets/
```

## Running the App

1. Open `Kitchen Manager/Kitchen Manager.xcodeproj` in Xcode.
2. Select an iOS simulator or a physical device.
3. Build and run the `Kitchen Manager` target.

The Xcode project currently sets `IPHONEOS_DEPLOYMENT_TARGET = 26.2`. If your local Xcode or iOS SDK does not support that target, adjust the deployment target in the Xcode project settings before building.

## AI Configuration

Open the in-app settings screen to configure:

- API key
- Base URL, for example `https://api.openai.com/v1`
- Model name, for example `gpt-4o-mini` or another OpenAI-compatible chat model

`AIChefEngine` appends `/chat/completions` when needed and requests JSON responses so the app can parse dish names, cooking tips, and ingredient lists.

The API key is stored in the system Keychain. Base URL and model settings remain in the app's local JSON state because they are not secrets.

## Data Persistence

On first launch, the app loads sample inventory, shopping, meal planning, and budget data. User changes are saved automatically to:

```text
~/Documents/kitchen_data.json
```

The saved state includes inventory items, shopping list state, weekly meal plans, budget records, hydration records, and non-secret AI settings. API keys are not written to this JSON file.

## Project Status

Kitchen Manager is an end-to-end iOS prototype rather than a static UI mock. It includes real local state management, cross-feature synchronization, budget and inventory logic, and configurable AI recipe generation. The most valuable next engineering step would be focused unit tests for the business logic in `AlertEngine`, `KitchenData`, and `KitchenStore`.
