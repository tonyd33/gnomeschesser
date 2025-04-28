#ifndef _LOG_H_
#define _LOG_H_
#include <ctime>

namespace tinylogger {

enum class LogLevel { Debug = 0, Info, Warning, Error, None };

inline LogLevel CURRENT_LOG_LEVEL = LogLevel::Debug; // Default to Debug

inline const char *level_to_string(LogLevel level) {
  switch (level) {
  case LogLevel::Debug:
    return "DEBUG";
  case LogLevel::Info:
    return "INFO";
  case LogLevel::Warning:
    return "WARNING";
  case LogLevel::Error:
    return "ERROR";
  default:
    return "UNKNOWN";
  }
}

inline void set_log_level(LogLevel level) { CURRENT_LOG_LEVEL = level; }

inline void log(LogLevel level, const char *const fmt, ...) {
  if (level < CURRENT_LOG_LEVEL) {
    return;
  }
  std::time_t now = std::time(nullptr);
  char timebuf[20];
  std::strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S",
                std::localtime(&now));

  va_list args;
  va_start(args, fmt);
  fprintf(stderr, "[%s] [%s]: ", timebuf, level_to_string(level));
  vfprintf(stderr, fmt, args);
  va_end(args);
}

} // namespace tinylogger

// Helper macros for easy use
#define LOG_DEBUG(fmt, ...)                                                    \
  tinylogger::log(tinylogger::LogLevel::Debug, fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)                                                     \
  tinylogger::log(tinylogger::LogLevel::Info, fmt, ##__VA_ARGS__)
#define LOG_WARNING(fmt, ...)                                                  \
  tinylogger::log(tinylogger::LogLevel::Warning, fmt, ##__VA_ARGS__)
#define LOG_ERROR(fmt, ...)                                                    \
  tinylogger::log(tinylogger::LogLevel::Error, fmt, ##__VA_ARGS__)

#define SET_LOG_LEVEL(level) tinylogger::set_log_level(level)

#endif /* _LOG_H_ */
