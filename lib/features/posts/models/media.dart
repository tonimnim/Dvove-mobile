class Media {
  final String url;
  final MediaType type;
  final String? thumbnailUrl;

  Media({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });

  factory Media.fromUrl(String url) {
    final extension = url.split('.').last.toLowerCase();
    MediaType type;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      type = MediaType.image;
    } else if (['mp4', 'mov', 'avi', 'webm'].contains(extension)) {
      type = MediaType.video;
    } else {
      type = MediaType.image; // Default to image
    }

    return Media(
      url: url,
      type: type,
    );
  }

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;
}

enum MediaType { image, video }