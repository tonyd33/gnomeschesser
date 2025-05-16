#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define BUF_SIZE 4096

void die(const char *msg) {
  perror(msg);
  exit(EXIT_FAILURE);
}

void get_timestamp(char *buf, size_t size) {
  time_t now = time(NULL);
  struct tm *tm_info = localtime(&now);
  strftime(buf, size, "%Y-%m-%d %H:%M:%S", tm_info);
}

void forward_and_log(int from_fd, int to_fd, FILE *log, const char *label) {
  char buf[BUF_SIZE];
  ssize_t n;
  while ((n = read(from_fd, buf, BUF_SIZE)) > 0) {
    // Write to destination fd
    write(to_fd, buf, n);

    if (log && label) {
      size_t i = 0;
      while (i < n) {
        size_t line_len = 0;
        while ((i + line_len) < n && buf[i + line_len] != '\n') {
          line_len++;
        }

        char timestamp[32];
        get_timestamp(timestamp, sizeof(timestamp));

        if ((i + line_len) < n && buf[i + line_len] == '\n') {
          // Full line
          fprintf(log, "[%s] [%s] %.*s\n", timestamp, label, (int)line_len,
                  &buf[i]);
          i += line_len + 1;
        } else {
          // Partial line
          fprintf(log, "[%s] [%s] %.*s", timestamp, label, (int)(n - i),
                  &buf[i]);
          break;
        }
      }
      fflush(log);
    }
  }
}

int main(int argc, char *argv[]) {
  if (argc < 3) {
    fprintf(stderr, "Usage: %s logfile program [args...]\n", argv[0]);
    return 1;
  }

  const char *log_path = argv[1];
  char **cmd = &argv[2];

  FILE *log = fopen(log_path, "a");
  if (!log)
    die("fopen");

  int in_pipe[2], out_pipe[2], err_pipe[2];
  if (pipe(in_pipe) == -1 || pipe(out_pipe) == -1 || pipe(err_pipe) == -1)
    die("pipe");

  pid_t pid = fork();
  if (pid == -1)
    die("fork");

  if (pid == 0) {
    // Child process
    dup2(in_pipe[0], STDIN_FILENO);
    dup2(out_pipe[1], STDOUT_FILENO);
    dup2(err_pipe[1], STDERR_FILENO);

    close(in_pipe[1]);
    close(out_pipe[0]);
    close(err_pipe[0]);

    execvp(cmd[0], cmd);
    perror("execvp");
    exit(1);
  }

  // Parent process
  close(in_pipe[0]);
  close(out_pipe[1]);
  close(err_pipe[1]);

  // Fork helper for stdin -> child stdin (log and forward)
  if (fork() == 0) {
    forward_and_log(STDIN_FILENO, in_pipe[1], log, "stdin");
    close(in_pipe[1]);
    exit(0);
  }

  // Fork helper for child stdout -> parent stdout
  if (fork() == 0) {
    forward_and_log(out_pipe[0], STDOUT_FILENO, log, "stdout");
    close(out_pipe[0]);
    exit(0);
  }

  // Fork helper for child stderr -> parent stderr
  if (fork() == 0) {
    forward_and_log(err_pipe[0], STDERR_FILENO, log, "stderr");
    close(err_pipe[0]);
    exit(0);
  }

  close(in_pipe[1]);
  close(out_pipe[0]);
  close(err_pipe[0]);

  // Wait for the child program
  int status;
  waitpid(pid, &status, 0);
  fclose(log);
  return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
