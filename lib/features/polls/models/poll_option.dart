class PollOption {
  final int id;
  final String optionText;
  final int voteCount;

  PollOption({
    required this.id,
    required this.optionText,
    required this.voteCount,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'],
      optionText: json['option_text'],
      voteCount: json['vote_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'option_text': optionText,
      'vote_count': voteCount,
    };
  }
}
