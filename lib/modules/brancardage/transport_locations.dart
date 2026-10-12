// Synthetic examples only. Never publish a private deployment catalog.
const transportLocations = <Map<String, String>>[
  {
    "id": "DEMO-SERVICE-A",
    "name": "Demo service A",
    "site": "Demo site",
    "building": "Demo building",
    "floor": "Demo level",
    "room": "",
    "full_name": "Demo service A — Demo building · Demo level",
  },
  {
    "id": "DEMO-SERVICE-B",
    "name": "Demo service B",
    "site": "Demo site",
    "building": "Demo building",
    "floor": "Demo level",
    "room": "",
    "full_name": "Demo service B — Demo building · Demo level",
  },
  {
    "id": "DEMO-ROOM-A",
    "name": "Demo service A",
    "site": "Demo site",
    "building": "Demo building",
    "floor": "Demo level",
    "room": "Demo room",
    "full_name": "Demo service A · Demo room — Demo building · Demo level",
    "parent_id": "DEMO-SERVICE-A",
  },
];

String normalizeLocation(String value) {
  var result = value.toLowerCase();
  const from = "àâäéèêëîïôöùûüç";
  const to = "aaaeeeeiioouuuc";
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result;
}
