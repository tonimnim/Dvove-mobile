# Posts Feature Implementation Plan

## Overview
Single-feed Twitter-like posts system with real-time alerts and enhanced content formatting for County Connect (Kaunti+).

## Architecture Principles
- **Single Feed**: No tabs - all content in one stream
- **Real-time Updates**: Alerts pushed instantly to feed and notifications
- **Enhanced Formatting**: Rich text with mentions, hashtags, and links
- **Twitter-like UI**: Clean, minimal design with focus on content
- **Offline-First**: Cache posts locally, sync when online

## Phase 1: Core Data Layer (Day 1)

### 1.1 Post Model
```dart
lib/features/posts/models/
├── post.dart           # Main post model with all fields
├── comment.dart        # Comment model
├── media.dart          # Media attachment model
└── engagement.dart     # Likes/comments counts
```

**Key Post Fields:**
- content (optional - can be media-only)
- type (announcement, job, event, alert)
- media_urls (max 4 images OR 1 video)
- priority (for alerts: high, medium, low)
- expires_at (for jobs/events)
- engagement metrics (likes, comments, views)

### 1.2 Posts Service
```dart
lib/features/posts/services/posts_service.dart
```
- Fetch posts with pagination
- Like/unlike posts
- Add/edit/delete comments
- Report posts
- Handle media uploads

### 1.3 Posts Provider
```dart
lib/features/posts/providers/posts_provider.dart
```
**State Management:**
- posts list with pagination state
- loading/refreshing states
- optimistic updates for likes
- real-time alert injection
- offline queue for actions

## Phase 2: Feed UI Components (Day 2)

### 2.1 PostCard Widget
```dart
lib/features/posts/widgets/
├── post_card.dart           # Main card component
├── post_header.dart         # Author, time, type badge
├── post_content.dart        # Enhanced text formatting
├── post_media.dart          # Image grid/video player
├── post_actions.dart        # Like, comment, share buttons
└── alert_banner.dart        # Special styling for alerts
```

**Design Specifications:**
- White cards with subtle borders
- Type badges(WE DONT WANT TYPE BADGE ON THE FEED BAGE) I THINK AN ICON WOULD BE BETTER.. (colored based on type)
- Priority indicators for alerts(ON HOW THEY ARE CREATED OK, NO OVER COMLICATING A THING PLEASE)
- "Expires in X days" for jobs/events
- Twitter-like engagement buttons WE NEED THE COMMENT AND THE LIKES ONLY... 

### 2.2 Enhanced Content Formatting
```dart
lib/features/posts/widgets/formatted_text.dart
```
**Features:**
- @mentions highlighting
- #hashtags linking
- URL auto-detection
- Phone number detection (+254...)
- Expandable long text (Read more...)
- Text size based on content length

### 2.3 Media Display
```dart
lib/features/posts/widgets/
├── image_grid.dart      # 1-4 images layout
├── video_player.dart    # Single video display
└── fullscreen_media.dart # Gallery view
```

**Layouts:**
- 1 image: Full width
- 2 images: Side by side
- 3 images: 2 top, 1 bottom
- 4 images: 2x2 grid

## Phase 3: Feed Screen Integration

### 3.1 Main Feed
```dart
lib/features/posts/screens/posts_feed.dart - cant we use the homescreen as its where the feed will be? or you want to like use posts_feed.dart as a compinent to be imported on the home page... just do what a professioal would do
```
**Components:**
- Pull-to-refresh
- Infinite scroll pagination
- Empty state (no posts)
- Error state with retry
- Loading shimmer effect

### 3.2 Real-time Alert Integration
**Alert Behavior:**
- High priority: Push to top (no animation...we are using the firebase laravel fcm to only push High priority type to the feeds as well onnotifications )
- Medium priority: Insert at top silently
- Low priority: Show in regular feed order
- Notification badge on new alerts

### 3.3 Feed Filters (Optional Quick Access)... we dont need this for now... we will show all posts on the home screen. No filter.. I am in a hurry to complete this... 
```dart
lib/features/posts/widgets/feed_filters.dart
```
- All Posts (default)
- Announcements only
- Jobs only
- Events only
- Active alerts

so dont include the 3.3

## Phase 4: Engagement Features (Day 4)

### 4.1 Like System
- Optimistic UI updates
- Heart animation on like
- Like count with abbreviation (1.2K)

### 4.2 Comments Bottom Sheet
```dart
lib/features/posts/screens/comments_sheet.dart
```
- Slide-up modal
- Real-time comment updates
- Reply to comments (optional)
- Edit/delete own comments

### 4.3 Share Options
- Share via WhatsApp
- Copy link
- Share to other apps

### 4.4 Report System
- Quick report reasons
- Optional description
- Confirmation feedback

## Phase 5: Performance & Polish (Day 5)

### 5.1 Caching Strategy
- Cache last 100 posts locally
- Preload images when on WiFi
- Store user interactions offline
- Sync when connection restored

### 5.2 Animations
- Smooth scroll animations
- Like button press effect
- New post slide-in animation
- Pull-to-refresh custom animation

### 5.3 Accessibility
- Screen reader support
- Contrast compliance
- Touch target sizes
- Focus management

## Implementation Order

### Week 1 Sprint:
**Day 1:**
- Post model and data structures
- Posts service with API integration
- Basic provider setup

**Day 2:**
- PostCard widget structure
- Enhanced content formatting
- Basic media display

**Day 3:**
- Complete feed screen
- Pull-to-refresh
- Infinite scroll

**Day 4:**
- Like functionality
- Comments system
- Share features

**Day 5:**
- Real-time alerts
- Caching implementation
- Polish and testing

## API Endpoints Used

### Public Endpoints:
- `GET /api/v1/posts` - Main feed
- `GET /api/v1/posts/{id}` - Single post
- `GET /api/v1/posts/{id}/comments` - Comments

### Authenticated Endpoints:
- `POST /api/v1/posts/{id}/like` - Like post
- `POST /api/v1/posts/{id}/unlike` - Unlike
- `POST /api/v1/posts/{id}/comment` - Add comment
- `PUT /api/v1/comments/{id}` - Edit comment
- `DELETE /api/v1/comments/{id}` - Delete comment
- `POST /api/v1/posts/{id}/report` - Report post

## Success Metrics
- Feed loads in < 2 seconds
- Smooth 60fps scrolling
- Offline actions queue properly
- Real-time alerts appear instantly
- Zero crashes in production

## Testing Checklist
- [ ] Posts load and display correctly
- [ ] Images/videos render properly
- [ ] Like/unlike works offline
- [ ] Comments sync when online
- [ ] Alerts appear in real-time
- [ ] Content formatting works
- [ ] Share functionality works
- [ ] Report system functional
- [ ] Pagination works smoothly
- [ ] Pull-to-refresh updates feed

## Next Steps After Posts
1. Search functionality
2. Jobs dedicated view
3. Notifications center
4. User profile enhancement
5. Officials dashboard (for posting)