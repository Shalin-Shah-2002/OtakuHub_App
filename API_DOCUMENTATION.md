# HiAnime Scraper API Documentation

## Overview

The HiAnime Scraper API provides a comprehensive RESTful interface for accessing anime data from HiAnime.to and MyAnimeList (MAL). It supports searching, browsing, filtering, retrieving details, episodes, and integrating with MAL for both public and user-authenticated endpoints.

- **Base URL:** `/`
- **Version:** 1.0.0
- **Docs:** `/docs` (Swagger UI), `/redoc` (ReDoc)

---

## Table of Contents
1. [Health Check](#health-check)
2. [Search](#search)
3. [Browse](#browse)
4. [Genre & Type](#genre--type)
5. [Advanced Filter](#advanced-filter)
6. [Anime Details](#anime-details)
7. [A-Z List](#a-z-list)
8. [Subbed / Dubbed](#subbed--dubbed)
9. [Producer / Studio](#producer--studio)
10. [Episodes](#episodes)
11. [MyAnimeList (MAL) Endpoints](#myanimelist-mal-endpoints)
12. [MAL User Authentication](#mal-user-authentication)
13. [Combined Search](#combined-search)

---

## 1. Health Check
- **GET /**
- **Response Example:**
```json
{
  "status": "online",
  "api": "HiAnime + MAL Scraper API",
  "version": "2.0.0",
  "mal_enabled": true,
  "total_endpoints": 24,
  "endpoints": { ... }
}
```

## 2. Search
- **GET /api/search?keyword=naruto&page=1**
- Search for anime by keyword.
- **Parameters:**
  - `keyword` (required): Search term
  - `page` (default: 1)
- **Response Example:**
```json
{
  "success": true,
  "count": 1,
  "page": 1,
  "data": [
    {
      "title": "Naruto",
      "url": "https://hianime.to/anime/naruto-677",
      "id": "naruto-677",
      "slug": "naruto-677",
      "thumbnail": "https://...jpg",
      "type": "TV",
      "duration": "23 min",
      "episodes_sub": 220,
      "episodes_dub": 220
    }
  ]
}
```

## 3. Browse
- **GET /api/popular**: Most popular anime
- **GET /api/top-airing**: Currently airing anime
- **GET /api/recently-updated**: Recently updated anime
- **GET /api/completed**: Completed anime
- **Parameters:**
  - `page` (default: 1)
- **Response Example:** (same as Search)

## 4. Genre & Type
- **GET /api/genre/{genre}**: Anime by genre
- **GET /api/type/{type_name}**: Anime by type (movie, tv, ova, ona, special, music)
- **Parameters:**
  - `genre` or `type_name`
  - `page` (default: 1)
- **Response Example:** (same as Search)

## 5. Advanced Filter
- **GET /api/filter**
- Filter anime by multiple criteria (type, status, rating, score, season, language, genres, sort, page).
- **Parameters:**
  - `type`, `status`, `rated`, `score`, `season`, `language`, `genres`, `sort`, `page`
- **Response Example:** (same as Search)

## 6. Anime Details
- **GET /api/anime/{slug}**
- Retrieve detailed information about an anime.
- **Parameters:**
  - `slug`: Anime slug (e.g., naruto-677)
- **Response Example:**
```json
{
  "success": true,
  "data": {
    "id": "naruto-677",
    "slug": "naruto-677",
    "title": "Naruto",
    "url": "https://hianime.to/anime/naruto-677",
    "thumbnail": "https://...jpg",
    "type": "TV",
    "status": "Finished",
    "episodes_sub": 220,
    "episodes_dub": 220,
    "mal_score": 7.9,
    "synopsis": "...",
    "genres": ["Action", "Adventure"],
    "studios": ["Studio Pierrot"]
  }
}
```

## 7. A-Z List
- **GET /api/az/{letter}**
- List anime alphabetically by first letter.
- **Parameters:**
  - `letter`: A-Z or 'other'
  - `page` (default: 1)
- **Response Example:** (same as Search)

## 8. Subbed / Dubbed
- **GET /api/subbed**: Anime with subtitles
- **GET /api/dubbed**: Dubbed anime
- **Parameters:**
  - `page` (default: 1)
- **Response Example:** (same as Search)

## 9. Producer / Studio
- **GET /api/producer/{producer_slug}**
- List anime by producer or studio.
- **Parameters:**
  - `producer_slug`: e.g., studio-pierrot
  - `page` (default: 1)
- **Response Example:** (same as Search)

## 10. Episodes
- **GET /api/episodes/{slug}**
- Retrieve full episode list for an anime.
- **Parameters:**
  - `slug`: Anime slug with ID
- **Response Example:**
```json
{
  "success": true,
  "count": 2,
  "data": [
    {
      "number": 1,
      "title": "Enter: Naruto Uzumaki!",
      "url": "https://hianime.to/episode/naruto-677-ep-1",
      "id": "naruto-677-ep-1",
      "japanese_title": "うずまきナルト登場!",
      "is_filler": false
    },
    {
      "number": 2,
      "title": "My Name is Konohamaru!",
      "url": "https://hianime.to/episode/naruto-677-ep-2",
      "id": "naruto-677-ep-2",
      "japanese_title": "木ノ葉丸登場!",
      "is_filler": false
    }
  ]
}
```

## 11. MyAnimeList (MAL) Endpoints
- **GET /api/mal/search?query=naruto&limit=10**: Search anime on MAL
- **GET /api/mal/anime/{mal_id}**: Get anime details from MAL
- **GET /api/mal/ranking?type=all&limit=10**: Get anime rankings from MAL
- **GET /api/mal/seasonal?year=2024&season=winter&limit=10**: Get seasonal anime from MAL
- **Response Example (Search):**
```json
{
  "success": true,
  "source": "myanimelist",
  "count": 1,
  "data": [
    {
      "mal_id": 20,
      "title": "Naruto",
      "main_picture": {"medium": "https://...jpg"},
      "mean_score": 7.9,
      "rank": 100,
      "popularity": 10,
      "num_episodes": 220,
      "status": "finished_airing",
      "genres": [{"id": 1, "name": "Action"}],
      "studios": [{"id": 1, "name": "Studio Pierrot"}],
      "media_type": "tv"
    }
  ]
}
```

## 12. MAL User Authentication
- **POST /api/mal/user/auth**: Get OAuth2 authorization URL
  - **Request Body:**
    ```json
    {
      "client_id": "YOUR_CLIENT_ID",
      "client_secret": "YOUR_CLIENT_SECRET",
      "redirect_uri": "YOUR_REDIRECT_URI"
    }
    ```
  - **Response Example:**
    ```json
    {
      "success": true,
      "message": "Open auth_url in browser to login. Save code_verifier for token exchange.",
      "privacy_notice": "We DO NOT store your credentials. This request is stateless.",
      "data": {
        "auth_url": "https://myanimelist.net/v1/oauth2/authorize?...",
        "code_verifier": "...",
        "state": "..."
      }
    }
    ```
- **POST /api/mal/user/token**: Exchange code for access token
  - **Request Body:**
    ```json
    {
      "client_id": "YOUR_CLIENT_ID",
      "client_secret": "YOUR_CLIENT_SECRET",
      "code": "CODE_FROM_CALLBACK",
      "code_verifier": "CODE_VERIFIER_FROM_AUTH",
      "redirect_uri": "YOUR_REDIRECT_URI"
    }
    ```
  - **Response Example:**
    ```json
    {
      "success": true,
      "message": "Save these tokens securely. We DO NOT store them.",
      "privacy_notice": "Tokens are returned to you only. Store them securely on your end.",
      "data": {
        "access_token": "...",
        "refresh_token": "...",
        "expires_in": 2678400,
        "token_type": "Bearer"
      }
    }
    ```
- **POST /api/mal/user/animelist**: Get user's anime list
  - **Request Body:**
    ```json
    {
      "client_id": "YOUR_CLIENT_ID",
      "access_token": "USER_ACCESS_TOKEN",
      "status": "watching",
      "limit": 100
    }
    ```
  - **Response Example:**
    ```json
    {
      "success": true,
      "privacy_notice": "We DO NOT store your data. This response is not logged.",
      "count": 1,
      "data": [
        {
          "anime": {"mal_id": 20, "title": "Naruto", ...},
          "status": "watching",
          "score": 8,
          "num_episodes_watched": 100,
          "updated_at": "2025-12-22T12:00:00Z"
        }
      ]
    }
    ```
- **POST /api/mal/user/profile**: Get authenticated user's MAL profile
  - **Request Body:**
    ```json
    {
      "client_id": "YOUR_CLIENT_ID",
      "access_token": "USER_ACCESS_TOKEN"
    }
    ```
  - **Response Example:**
    ```json
    {
      "success": true,
      "privacy_notice": "We DO NOT store your profile data.",
      "data": {
        "id": 12345,
        "name": "your_username",
        "picture": "https://...jpg",
        "anime_statistics": { ... }
      }
    }
    ```

**Privacy Notice:** Credentials and tokens are never stored on the server. All authentication is stateless and secure.

## 13. Combined Search
- **GET /api/combined/search?query=naruto&limit=5**
- Search both HiAnime and MAL simultaneously. Returns results from both sources for comparison.
- **Response Example:**
```json
{
  "success": true,
  "query": "naruto",
  "sources": {
    "hianime": {
      "enabled": true,
      "results": [ { ... } ],
      "count": 1,
      "error": null
    },
    "myanimelist": {
      "enabled": true,
      "results": [ { ... } ],
      "count": 1,
      "error": null
    }
  }
}
```

---

## Response Models
- All endpoints return a JSON object with at least `success` and `data` fields. Some include `count`, `page`, or `error`.
- Errors are returned with `success: false` and an `error` message.

---

## Error Handling
- Standardized error responses for all endpoints.
- HTTP status codes and error messages are provided for all failures.

---

## Example Usage

### Search Example
```
GET /api/search?keyword=one%20piece&page=1
```
Response:
```
{
  "success": true,
  "count": 1,
  "page": 1,
  "data": [
    {
      "id": "one-piece-100",
      "title": "One Piece",
      ...
    }
  ]
}
```

---

For more details, see the [OpenAPI docs](/docs) or [ReDoc](/redoc) in your running API instance.
Genre Browser Screen - Grid of genres (Action, Comedy, Romance, etc.) that users can tap to browse

Recently Updated Feed - "New Episodes" tab showing latest releases

Advanced Filter Screen - Let users filter by:

Type (TV, Movie, OVA)
Status (Airing, Completed)
Score range
Season/Year
Language (Sub/Dub)
Studio/Producer Pages - Tap on a studio name to see all their anime

A-Z Index - Alphabet bar for quick browsing

Subbed vs Dubbed Toggle - Quick filter for language preference

"Completed Anime" Section - Perfect for users who want to binge