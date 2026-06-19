import 'package:url_launcher/url_launcher.dart';

/// Opens phone dialer or WhatsApp chat for the seller (no in-app chat server).
class ContactService {
  static Future<bool> dialPhone(String phone) async {
    final normalized = _digitsOnly(phone);
    if (normalized.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: normalized);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }

  static Future<bool> openWhatsApp(String phone) async {
    final normalized = _digitsOnly(phone);
    if (normalized.isEmpty) return false;
    // wa.me expects country code without + ; assume Pakistan 92 if 10–11 digit local
    String wa = normalized;
    if (wa.length == 10 && wa.startsWith('3')) {
      wa = '92$wa';
    } else if (wa.length == 11 && wa.startsWith('0')) {
      wa = '92${wa.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$wa');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }
}
