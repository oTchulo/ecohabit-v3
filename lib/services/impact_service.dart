class Impact {
  final double? co2, kwh;
  const Impact({this.co2, this.kwh});
}

class ImpactService {
  static const version = 'impacto-v1';
  // EIA: https://www.eia.gov/energyexplained/electricity/measuring-electricity.php
  // Potência informada pelo usuário a partir da etiqueta da lâmpada.
  Impact estimate(String activityCode, int quantity, {double? watts}) {
    if (activityCode == 'luzes_apagadas' &&
        watts != null &&
        watts.isFinite &&
        watts > 0) {
      final kwh = watts * (quantity / 60000);
      return kwh.isFinite ? Impact(kwh: kwh) : const Impact();
    }
    // Sem material/massa e cenário motorizado validados, não estimar CO₂.
    return const Impact();
  }
}
