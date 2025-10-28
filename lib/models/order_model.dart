class OrderModel {
  final String pickupLocationName;
  final double pickupLatitude;
  final double pickupLongitude;
  final DateTime pickupDate;
  final String slotTime;
  final String scrapImageUrl;
  final String scrapyardId;
  final String scrapyardName;
  final double scrapyardLatitude;
  final double scrapyardLongitude;
  final String pickupState;
  final String pickupCity;

  OrderModel({
    required this.pickupLocationName,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupDate,
    required this.slotTime,
    required this.scrapImageUrl,
    required this.scrapyardId,
    required this.scrapyardName,
    required this.scrapyardLatitude,
    required this.scrapyardLongitude,
    required this.pickupState,
    required this.pickupCity,
  });
}
