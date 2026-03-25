import 'package:flutter/material.dart';
import 'tire_model.dart';
import 'settings.dart';

const Color kKFUPMGreen = Color(0xFF008540);
const Color kKFUPMGold  = Color(0xFFDAC961);
const Color kNavGrey    = Color(0xFF424242);

class TireCard extends StatelessWidget {
  const TireCard({
    super.key,
    required this.tire,
    required this.onInflate,
    required this.onDeflate,
  });

  final Tire tire;
  final VoidCallback onInflate;
  final VoidCallback onDeflate;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kKFUPMGold,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status dot
            Row(
              children: [
                Expanded(
                  child: Text(
                    tire.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tire.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ✅ Live PSI directly from tire.psi
            Text(
              AppSettings.fmtPsi1(tire.psi),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 6),

            // ✅ State shown for future real use
            Text(
              'State: ${tire.actuatorLabel}',
              style: TextStyle(
                color: Colors.black.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            const Spacer(),

            // Buttons (navigation only)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionBtn(
                  icon: Icons.arrow_downward,
                  text: 'Deflate',
                  onTap: onDeflate,
                ),
                _actionBtn(
                  icon: Icons.arrow_upward,
                  text: 'Inflate',
                  onTap: onInflate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: kNavGrey,
        foregroundColor: Colors.white,
        minimumSize: const Size(10, 38),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: kKFUPMGreen),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
