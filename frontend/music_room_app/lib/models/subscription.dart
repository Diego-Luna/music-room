// VI.3 bonus — free vs paid subscription.
// Mirrors the backend contract: GET /subscription/plans returns a list of
// SubscriptionPlan, GET/PUT /subscription/me return a Subscription.

enum SubscriptionTier {
  free,
  premium;

  /// Backend serialises the tier as the uppercase enum name ('FREE'/'PREMIUM').
  static SubscriptionTier fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PREMIUM':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }

  String toJson() {
    switch (this) {
      case SubscriptionTier.free:
        return 'FREE';
      case SubscriptionTier.premium:
        return 'PREMIUM';
    }
  }

  bool get isPremium => this == SubscriptionTier.premium;
}

/// One offer in the catalogue (SubscriptionPlanDto on the backend).
class SubscriptionPlan {
  final SubscriptionTier tier;
  final String label;
  final String price; // display string; '0' for the free plan
  final List<String> features;

  const SubscriptionPlan({
    required this.tier,
    required this.label,
    required this.price,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      tier: SubscriptionTier.fromString(json['tier'] as String?),
      label: json['label'] as String? ?? '',
      price: json['price']?.toString() ?? '0',
      features: List<String>.from(json['features'] ?? const []),
    );
  }

  bool get isFree => price == '0' || price == '0.00';
}

/// The signed-in user's current subscription (SubscriptionDto on the backend).
class Subscription {
  final SubscriptionTier tier;

  const Subscription({required this.tier});

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(tier: SubscriptionTier.fromString(json['tier'] as String?));
  }
}
