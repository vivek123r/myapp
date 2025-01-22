import 'package:logger/logger.dart';

class LoggerUtil {
  static final Logger logger = Logger(
    printer: PrettyPrinter(), // Adjust the printer for console/file logs
  );
}