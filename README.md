# Anime App

A Flutter application for searching and browsing anime with episode information using the HiAnime Scraper API.

## Features

- 🔍 **Search Anime**: Search for your favorite anime by keyword
- 📊 **Popular Anime**: Browse the most popular anime
- 📖 **Anime Details**: View detailed information including synopsis, score, genres, and studios
- 📺 **Episode List**: Access complete episode listings with filler indicators
- 🔗 **Episode Links**: Click on episodes to get streaming links
- ♾️ **Infinite Scroll**: Load more results as you scroll
- 🎨 **GetX State Management**: Reactive and efficient state management
- 🌙 **Dark Theme Support**: Modern UI with light and dark themes

## Project Structure

```
lib/
├── main.dart                           # App entry point with GetX setup
├── controllers/
│   └── anime_controller.dart          # GetX controller for state management
├── models/
│   ├── request/                       # Request models folder
│   │   ├── search_anime_request.dart  # Search anime request parameters
│   │   └── get_episodes_request.dart  # Get episodes request parameters
│   └── response/                      # Response models folder
│       ├── anime_model.dart           # Anime data model (HiAnime format)
│       ├── anime_list_response.dart   # Anime list API response
│       ├── episode_model.dart         # Episode data model
│       └── episode_list_response.dart # Episode list response
├── services/
│   └── api_service.dart               # API client service for HiAnime API
├── views/
│   ├── home_screen.dart               # Main screen with popular anime
│   ├── search_screen.dart             # Search anime screen
│   └── anime_detail_screen.dart       # Anime details with clickable episodes
└── utils/                             # Utility functions
```

## Dependencies

- **get**: GetX state management
- **http**: HTTP client for API calls
- **json_annotation**: JSON serialization annotations
- **cached_network_image**: Efficient image loading and caching
- **build_runner**: Code generation
- **json_serializable**: JSON serialization code generator

## API Integration

This app uses the **HiAnime Scraper API** for anime data.

### Setup API Base URL

1. Open `lib/services/api_service.dart`
2. Replace `YOUR_API_BASE_URL` with your HiAnime API URL:
```dart
static const String baseUrl = 'https://your-api-url.com'; // Your API URL
```

### Available Endpoints

1. **Search Anime**: `/api/search?keyword={query}&page={page}`
2. **Popular Anime**: `/api/popular?page={page}`
3. **Get Anime Details**: `/api/anime/{slug}`
4. **Get Episodes**: `/api/episodes/{slug}`
5. **Top Airing**: `/api/top-airing?page={page}`

### Request Models

- **SearchAnimeRequest**: Parameters for searching anime
  - `keyword`: Search term (required)
  - `page`: Page number for pagination

- **GetEpisodesRequest**: Parameters for getting episodes
  - `slug`: The anime slug (required)

### Response Models

- **AnimeModel**: Complete anime information
  - `id`, `slug`, `title`, `url`, `thumbnail`
  - `type`, `status`, `duration`
  - `episodesSub`, `episodesDub`, `malScore`
  - `synopsis`, `genres[]`, `studios[]`

- **EpisodeModel**: Episode information
  - `number`, `title`, `url`, `id`
  - `japaneseTitle`, `isFiller`

- **AnimeListResponse**: List of anime
  - `success`, `count`, `page`, `data[]`

- **EpisodeListResponse**: List of episodes
  - `success`, `count`, `data[]`

## Getting Started

### Prerequisites

- Flutter SDK (^3.10.4)
- Dart SDK
- An IDE (VS Code, Android Studio, etc.)
- HiAnime Scraper API URL

### Installation

1. Clone the repository

2. Update API URL in `lib/services/api_service.dart`:
   ```dart
   static const String baseUrl = 'https://your-api-url.com';
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Generate JSON serialization code:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. Run the app:
   ```bash
   flutter run
   ```

## Usage

### Search for Anime

1. Tap the search icon in the app bar
2. Enter an anime title
3. Press Enter to search
4. Scroll down to load more results

### View Anime Details

1. Tap on any anime card from the home or search screen
2. View detailed information including:
   - Cover image and thumbnail
   - MAL score and rating
   - Episode count (Sub/Dub)
   - Type and Status
   - Genres and Studios
   - Synopsis
   - Complete episode list

### Watch Episodes

1. In the anime details screen, scroll to the episodes section
2. **Click on any episode** to view its details
3. A dialog will appear showing:
   - Episode title (English and Japanese)
   - Episode streaming URL
   - Filler indicator (if applicable)
4. Click "Open Link" to copy/open the episode URL
5. Episodes with orange avatars are filler episodes

### Browse Popular Anime

1. The home screen displays the most popular anime
2. Scroll down to load more anime

## Features Explained

### Episode Link Feature
- Click any episode in the list
- Get instant access to the episode streaming URL
- Filler episodes are clearly marked
- Japanese titles are displayed when available

### GetX State Management
- Reactive programming with `.obs` observables
- Efficient rebuilds with `Obx()` widget
- Simple navigation with `Get.to()`
- Easy dependency injection with `Get.put()` and `Get.find()`

## Customization

### Change API Base URL

Update the `baseUrl` in [api_service.dart](lib/services/api_service.dart):
```dart
static const String baseUrl = 'https://your-new-api-url.com';
```

### Add More API Endpoints

The HiAnime API supports additional endpoints:
- `/api/top-airing` - Currently airing anime
- `/api/recently-updated` - Recently updated anime
- `/api/genre/{genre}` - Filter by genre
- `/api/filter` - Advanced filtering

You can add these to `api_service.dart` and create corresponding methods in the controller.

## API Response Format

The HiAnime API returns responses in this format:

```json
{
  "success": true,
  "count": 1,
  "page": 1,
  "data": [
    {
      "id": "naruto-677",
      "slug": "naruto-677",
      "title": "Naruto",
      "thumbnail": "https://...",
      "type": "TV",
      "episodes_sub": 220,
      "episodes_dub": 220,
      "mal_score": 7.9
    }
  ]
}
```

## Notes

- Make sure your HiAnime API is accessible and running
- The API base URL must be set correctly in `api_service.dart`
- Image loading is cached to improve performance
- Episode URLs are provided by the API and can be opened directly
- Filler episodes are indicated with an orange avatar and "Filler" chip

## Troubleshooting

### "Failed to search anime" Error
- Check if your API URL is correct in `api_service.dart`
- Ensure the API server is running and accessible
- Check your internet connection

### Images Not Loading
- Verify the API is returning valid thumbnail URLs
- Check if cached_network_image package is installed

### Episode Links Not Working
- Ensure the episode URLs from the API are valid
- Check if the API is returning the `url` field for episodes

## Future Enhancements

- [ ] Add URL launcher to open episode links in browser
- [ ] Implement video player for episodes
- [ ] Add favorites/watchlist functionality
- [ ] Implement local database for offline access
- [ ] Add filter options (genre, type, status)
- [ ] Include character and staff information
- [ ] Add anime recommendations
- [ ] Support for MAL integration endpoints

## License

This project is open source and available under the MIT License.


## Features

- 🔍 **Search Anime**: Search for your favorite anime by title
- 📊 **Top Anime**: Browse the top-rated anime
- 📖 **Anime Details**: View detailed information including synopsis, score, genres, and status
- 📺 **Episode List**: Access complete episode listings for each anime
- ♾️ **Infinite Scroll**: Load more results as you scroll
- 🎨 **Material Design 3**: Modern UI with light and dark theme support

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── controllers/
│   └── anime_controller.dart          # State management controller
├── models/
│   ├── request/                       # Request models folder
│   │   ├── search_anime_request.dart  # Search anime request parameters
│   │   └── get_episodes_request.dart  # Get episodes request parameters
│   └── response/                      # Response models folder
│       ├── anime_model.dart           # Anime data model
│       ├── anime_list_response.dart   # Anime list API response
│       ├── episode_model.dart         # Episode data model
│       └── episode_list_response.dart # Episode list API response
├── services/
│   └── api_service.dart               # API client service
├── views/
│   ├── home_screen.dart               # Main screen with top anime
│   ├── search_screen.dart             # Search anime screen
│   └── anime_detail_screen.dart       # Anime details with episodes
└── utils/                             # Utility functions (empty for now)
```

## Dependencies

- **provider**: State management
- **http**: HTTP client for API calls
- **json_annotation**: JSON serialization annotations
- **cached_network_image**: Efficient image loading and caching
- **build_runner**: Code generation
- **json_serializable**: JSON serialization code generator

## API Integration

This app uses the [Jikan API](https://jikan.moe/) - an unofficial MyAnimeList API.

### Available Endpoints

1. **Search Anime**: `/anime?q={query}`
2. **Get Anime Details**: `/anime/{id}`
3. **Get Episodes**: `/anime/{id}/episodes`
4. **Top Anime**: `/top/anime`

### Request Models

- **SearchAnimeRequest**: Parameters for searching anime
  - `query`: Search term
  - `page`: Page number for pagination
  - `limit`: Number of results per page
  - `type`: Anime type (tv, movie, ova, etc.)
  - `status`: Airing status
  - `orderBy`: Sort field
  - `sort`: Sort direction

- **GetEpisodesRequest**: Parameters for getting episodes
  - `animeId`: The anime ID (required)
  - `page`: Page number for pagination

### Response Models

- **AnimeModel**: Complete anime information
- **EpisodeModel**: Episode information
- **AnimeListResponse**: List of anime with pagination
- **EpisodeListResponse**: List of episodes with pagination

## Getting Started

### Prerequisites

- Flutter SDK (^3.10.4)
- Dart SDK
- An IDE (VS Code, Android Studio, etc.)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate JSON serialization code:
   ```bash
   flutter pub run build_runner build
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Usage

### Search for Anime

1. Tap the search icon in the app bar
2. Enter an anime title
3. Press Enter or tap the search button
4. Scroll down to load more results

### View Anime Details

1. Tap on any anime card from the home or search screen
2. View detailed information including:
   - Cover image
   - Score and rating
   - Episode count
   - Status (Airing, Completed, etc.)
   - Genres
   - Synopsis
   - Complete episode list

### Browse Top Anime

1. The home screen displays the top-rated anime
2. Scroll down to load more anime

## Customization

### Change API Base URL

If you want to use a different API or host your own Jikan instance, update the `baseUrl` in api_service.dart:

```dart
static const String baseUrl = 'https://your-api-url.com/v4';
```

### Add More Request Parameters

You can extend the request models to include more parameters supported by the Jikan API. Check the [Jikan API documentation](https://docs.api.jikan.moe/) for available parameters.

## Notes

- The Jikan API has rate limiting. Be mindful of request frequency.
- Image loading is cached to improve performance and reduce network usage.
- The app uses Provider for state management - you can easily switch to another solution like Riverpod or Bloc.

## Future Enhancements

- [ ] Add favorites/watchlist functionality
- [ ] Implement local database for offline access
- [ ] Add user authentication
- [ ] Include character and staff information
- [ ] Add anime recommendations
- [ ] Implement video player for trailers
- [ ] Add filters for advanced search

## License

This project is open source and available under the MIT License.
