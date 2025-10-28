class USState {
  final String name;
  final String abbreviation;
  final List<String> cities;

  const USState({
    required this.name,
    required this.abbreviation,
    required this.cities,
  });
}

const List<USState> usStates = [
  USState(
    name: 'Ohio',
    abbreviation: 'OH',
    cities: [
      'Cincinnati Metro Area',
      'Dayton Metro Area',
      'Columbus Metro Area',
    ],
  ),
  // ... Add more states as needed
];
