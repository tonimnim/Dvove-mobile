import 'poll_option.dart';

class Poll {
  final int id;
  final String title;
  final String type;
  final String scope;
  final String status;
  final String showResults;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;
  final County? county;
  final List<PollOption> options;
  final int totalVotes;
  final double? averageRating;
  final bool userHasVoted;
  final dynamic userVote;
  final bool canVote;

  Poll({
    required this.id,
    required this.title,
    required this.type,
    required this.scope,
    required this.status,
    required this.showResults,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.county,
    this.options = const [],
    this.totalVotes = 0,
    this.averageRating,
    this.userHasVoted = false,
    this.userVote,
    this.canVote = true,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    List<PollOption> parsedOptions = [];
    if (json['options'] != null) {
      parsedOptions = (json['options'] as List)
          .map((option) => PollOption.fromJson(option))
          .toList();
    }

    County? parsedCounty;
    if (json['county'] != null) {
      parsedCounty = County.fromJson(json['county']);
    }

    return Poll(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      scope: json['scope'],
      status: json['status'],
      showResults: json['show_results'],
      startsAt: DateTime.parse(json['starts_at']),
      endsAt: DateTime.parse(json['ends_at']),
      createdAt: DateTime.parse(json['created_at']),
      county: parsedCounty,
      options: parsedOptions,
      totalVotes: json['total_votes'] ?? 0,
      averageRating: json['average_rating']?.toDouble(),
      userHasVoted: json['user_has_voted'] ?? false,
      userVote: json['user_vote'],
      canVote: json['can_vote'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'scope': scope,
      'status': status,
      'show_results': showResults,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'county': county?.toJson(),
      'options': options.map((o) => o.toJson()).toList(),
      'total_votes': totalVotes,
      'user_has_voted': userHasVoted,
      'user_vote': userVote,
      'can_vote': canVote,
    };
  }

  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';
  bool get isSingleChoice => type == 'single_choice';
  bool get isYesNo => type == 'yes_no';
  bool get isRating => type == 'rating';
  bool get canShowResults =>
      showResults == 'live' ||
      (showResults == 'after_vote' && userHasVoted) ||
      (showResults == 'after_close' && isClosed);
}

class County {
  final int id;
  final String name;

  County({
    required this.id,
    required this.name,
  });

  factory County.fromJson(Map<String, dynamic> json) {
    return County(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
