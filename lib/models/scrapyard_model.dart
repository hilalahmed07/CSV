class ScrapyardModel {
  final String id;
  final String address;
  final String latitude;
  final String longitude;
  final String name;
  final String openTill;
  final double rating;
  final String state;
  final String zipCode;
  final String city;

  ScrapyardModel({
    required this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.openTill,
    required this.rating,
    required this.state,
    required this.zipCode,
    required this.city,
  });

  // Factory method to create ScrapyardModel from JSON
  factory ScrapyardModel.fromJson(Map<String, dynamic> json) {
    return ScrapyardModel(
      id: json['id'] as String,
      address: json['address'] as String,
      latitude: json['latitude'].toString(),
      longitude: json['longitude'].toString(),
      name: json['name'] as String,
      openTill: json['openTill'] as String,
      rating: (json['rating'] as num).toDouble(),
      state: json['state'] as String,
      zipCode: json['zipCode'] as String,
      city: json['city'] as String,
    );
  }

  // Method to convert ScrapyardModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'openTill': openTill,
      'rating': rating,
      'state': state,
      'zipCode': zipCode,
      'city': city,
    };
  }
}
