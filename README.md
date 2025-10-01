# Post API Documentation for Mobile Developer

## Post Model Structure

### Post Types
- `announcement` - General announcements from officials
- `job` - Job postings
- `event` - Events happening in the county
- `alert` - Important/urgent alerts

### Post Fields
```json
{
  "id": 1,
  "title": "County Health Initiative",
  "content": "Full post content here...",
  "excerpt": "First 150 characters...", // Only in list view
  "type": "announcement",
  "media_urls": [], // Array of media URLs from Spatie Media Library
  "county": {
    "id": 1,
    "name": "Nairobi",
    "slug": "nairobi"
  },
  "author": {
    "id": 10,
    "official_name": "John Doe",
    "profile_photo": "url_to_photo"
  },
  "author_name": "John Doe",
  "likes_count": 45,
  "comments_count": 12,
  "views_count": 234,
  "is_liked": true, // Only when user is authenticated
  "created_at": "2025-01-21T10:30:00Z",
  "updated_at": "2025-01-21T10:30:00Z",
  "human_time": "2 hours ago"
}
```

### Additional Fields (in database, not in API response)
- `comments_enabled`: boolean
- `status`: "published" or "draft"
- `is_pinned`: boolean (pinned posts appear first)
- `event_date`: timestamp (for events)
- `location`: string (for events)
- `priority`: "high", "medium", "low" (for alerts)
- `published_at`: timestamp
- `expires_at`: timestamp (for jobs/events)

## API Endpoints

### Public Endpoints (No Authentication Required)

#### 1. Get All Posts
```
GET /api/v1/posts
```

Query Parameters:
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 20, max: 100)
- `county_id`: Filter by county
- `type`: Filter by type (announcement, job, event, alert)
- `search`: Search in title and content

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "County Health Initiative",
      "content": "Full content...",
      "excerpt": "First 150 characters...",
      "type": "announcement",
      // ... other fields
    }
  ],
  "links": {
    "first": "http://10.0.2.2:8000/api/v1/posts?page=1",
    "last": "http://10.0.2.2:8000/api/v1/posts?page=5",
    "prev": null,
    "next": "http://10.0.2.2:8000/api/v1/posts?page=2"
  },
  "meta": {
    "current_page": 1,
    "from": 1,
    "last_page": 5,
    "per_page": 20,
    "to": 20,
    "total": 95
  }
}
```

#### 2. Get Single Post
```
GET /api/v1/posts/{id}
```

Response:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "title": "County Health Initiative",
    "content": "Full content here...",
    // No excerpt field when viewing single post
    "type": "announcement",
    // ... all other fields
  }
}
```

#### 3. Get Posts by County
```
GET /api/v1/counties/{county_id}/posts
```

Same response format as Get All Posts

#### 4. Get Post Comments
```
GET /api/v1/posts/{post_id}/comments
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "content": "Great initiative!",
      "user": {
        "id": 5,
        "username": "john_doe",
        "profile_photo": "url_to_photo",
        "is_official": false
      },
      "created_at": "2025-01-21T10:30:00Z",
      "human_time": "2 hours ago",
      "is_mine": true // Only if authenticated
    }
  ],
  "meta": {
    "current_page": 1,
    "total": 12
  }
}
```

### Authenticated User Endpoints

Headers Required:
```
Authorization: Bearer {token}
Accept: application/json
```

#### 5. Like a Post
```
POST /api/v1/posts/{post_id}/like
```

Response:
```json
{
  "success": true,
  "message": "Post liked successfully",
  "data": {
    "is_liked": true,
    "likes_count": 46
  }
}
```

#### 6. Unlike a Post
```
POST /api/v1/posts/{post_id}/unlike
```

Response:
```json
{
  "success": true,
  "message": "Post unliked successfully",
  "data": {
    "is_liked": false,
    "likes_count": 45
  }
}
```

#### 7. Comment on a Post
```
POST /api/v1/posts/{post_id}/comment
```

Request Body:
```json
{
  "content": "This is my comment"
}
```

Response:
```json
{
  "success": true,
  "message": "Comment added successfully",
  "data": {
    "id": 13,
    "content": "This is my comment",
    "user": {
      "id": 5,
      "username": "john_doe",
      "profile_photo": null,
      "is_official": false
    },
    "created_at": "2025-01-21T12:45:00Z",
    "human_time": "just now",
    "is_mine": true
  }
}
```

#### 8. Report a Post
```
POST /api/v1/posts/{post_id}/report
```

Request Body:
```json
{
  "reason": "inappropriate",
  "description": "Contains offensive content"
}
```

Reason options:
- `spam`
- `inappropriate`
- `misinformation`
- `harassment`
- `other`

Response:
```json
{
  "success": true,
  "message": "Post reported successfully"
}
```

#### 9. Update Comment
```
PUT /api/v1/comments/{comment_id}
```

Request Body:
```json
{
  "content": "Updated comment content"
}
```

Response:
```json
{
  "success": true,
  "message": "Comment updated successfully",
  "data": {
    // Updated comment object
  }
}
```

#### 10. Delete Comment
```
DELETE /api/v1/comments/{comment_id}
```

Response:
```json
{
  "success": true,
  "message": "Comment deleted successfully"
}
```

#### 11. Get Liked Posts (User's liked posts)
```
GET /api/v1/user/liked-posts
```

Same response format as Get All Posts

### Official-Only Endpoints

These endpoints require the user to have the "official" role.

#### 12. Create Post
```
POST /api/v1/official/posts
```

Request Body:
```json
{
  "title": "New Health Initiative",
  "content": "Detailed content here...",
  "type": "announcement",
  "comments_enabled": true,
  "event_date": "2025-02-15T10:00:00Z", // For events
  "location": "County Hall", // For events
  "priority": "high", // For alerts
  "expires_at": "2025-03-01T23:59:59Z" // For jobs/events
}
```

Response:
```json
{
  "success": true,
  "message": "Post created successfully",
  "data": {
    // Full post object
  }
}
```

#### 13. Update Post
```
PUT /api/v1/official/posts/{post_id}
```

Request Body: Same as Create Post

Response:
```json
{
  "success": true,
  "message": "Post updated successfully",
  "data": {
    // Updated post object
  }
}
```

#### 14. Delete Post
```
DELETE /api/v1/official/posts/{post_id}
```

Response:
```json
{
  "success": true,
  "message": "Post deleted successfully"
}
```

#### 15. Get My Posts (Official's posts)
```
GET /api/v1/official/my-posts
```

Query Parameters:
- `status`: Filter by status (published, draft)
- `type`: Filter by type

Same response format as Get All Posts

#### 16. Get Analytics
```
GET /api/v1/official/analytics
```

Response:
```json
{
  "success": true,
  "data": {
    "total_posts": 45,
    "total_views": 12340,
    "total_likes": 890,
    "total_comments": 234,
    "posts_by_type": {
      "announcement": 20,
      "job": 10,
      "event": 10,
      "alert": 5
    },
    "top_posts": [
      {
        "id": 1,
        "title": "Most viewed post",
        "views_count": 1234,
        "likes_count": 89
      }
    ]
  }
}
```

## Error Responses

### Validation Error (422)
```json
{
  "success": false,
  "errors": {
    "title": ["The title field is required."],
    "content": ["The content must be at least 10 characters."]
  }
}
```

### Not Found (404)
```json
{
  "success": false,
  "message": "Post not found"
}
```

### Unauthorized (401)
```json
{
  "success": false,
  "message": "Unauthenticated"
}
```

### Forbidden (403)
```json
{
  "success": false,
  "message": "You are not authorized to perform this action"
}
```

### Rate Limit (429)
```json
{
  "success": false,
  "message": "Too many requests. Please try again later.",
  "retry_after": 60
}
```

## Media Handling

Posts can have images and documents attached. Use multipart/form-data when creating/updating posts with media:

```
POST /api/v1/official/posts
Content-Type: multipart/form-data

title: "Post with image"
content: "Content here"
type: "announcement"
image: [binary file data]
documents[]: [pdf file data]
```

The response will include media URLs in the `media_urls` field.

## Optimization Notes

1. **Eager Loading**: All post queries automatically include user and county data to prevent N+1 queries
2. **Caching**: Frequently accessed posts are cached for 5 minutes
3. **Pagination**: Always paginate results, default 20 per page
4. **Indexes**: Database has indexes on:
   - county_id + status + published_at
   - user_id + status
   - type + county_id
   - is_pinned

## Rate Limits

- Guest users: 60 requests per minute
- Authenticated users: 600 requests per minute
- Officials creating posts: 30 posts per hour

## Flutter Integration Tips

1. **Base URL**: Use `http://10.0.2.2:8000/api/v1` for Android emulator
2. **Token Storage**: Store the auth token securely using flutter_secure_storage
3. **Pagination**: Implement infinite scroll using the pagination links
4. **Caching**: Cache posts locally and sync when online
5. **Real-time Updates**: Consider implementing FCM for new post notifications
6. **Image Loading**: Use cached_network_image for efficient image loading
7. **Error Handling**: Always check `success` field before processing data
