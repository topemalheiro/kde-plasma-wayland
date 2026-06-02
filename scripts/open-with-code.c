#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <linux/limits.h>

char *expand_home(const char *path) {
    if (strncmp(path, "$HOME", 5) == 0) {
        char *home = getenv("HOME");
        if (home) {
            size_t len = strlen(home) + strlen(path) - 5 + 1;
            char *result = malloc(len);
            snprintf(result, len, "%s%s", home, path + 5);
            return result;
        }
    }
    return strdup(path);
}

char *strip_file_prefix(const char *url) {
    if (strncmp(url, "file://", 7) == 0) {
        return strdup(url + 7);
    } else if (strncmp(url, "file:", 5) == 0) {
        return strdup(url + 5);
    }
    return strdup(url);
}

void process_path(const char *path) {
    char target[PATH_MAX] = {0};

    // Check if it's a .desktop file
    size_t len = strlen(path);
    if (len > 8 && strcmp(path + len - 8, ".desktop") == 0) {
        FILE *f = fopen(path, "r");
        if (f) {
            char line[4096];
            int is_link = 0;
            char url_buf[4096] = {0};

            while (fgets(line, sizeof(line), f)) {
                line[strcspn(line, "\n")] = 0;

                if (strncmp(line, "Type=", 5) == 0) {
                    if (strcmp(line + 5, "Link") == 0) {
                        is_link = 1;
                    }
                } else if (strncmp(line, "URL", 3) == 0) {
                    char *eq = strchr(line, '=');
                    if (eq) {
                        strncpy(url_buf, eq + 1, sizeof(url_buf) - 1);
                    }
                }
            }
            fclose(f);

            if (is_link && url_buf[0] != '\0') {
                char *stripped = strip_file_prefix(url_buf);
                char *expanded = expand_home(stripped);
                strncpy(target, expanded, sizeof(target) - 1);
                free(stripped);
                free(expanded);
            }
        }
    }

    if (target[0] == '\0') {
        strncpy(target, path, sizeof(target) - 1);
    }

    // Resolve symlinks and relative paths
    char resolved[PATH_MAX];
    if (realpath(target, resolved) != NULL) {
        strncpy(target, resolved, sizeof(target) - 1);
    }

    // Open in VS Code: if it's a directory
    struct stat st;
    if (stat(target, &st) == 0 && S_ISDIR(st.st_mode)) {
        pid_t pid = fork();
        if (pid == 0) {
            execlp("code", "code", target, NULL);
            perror("code");
            _exit(1);
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;

    for (int i = 1; i < argc; i++) {
        process_path(argv[i]);
    }

    // Wait for all children
    while (wait(NULL) > 0);

    return 0;
}
