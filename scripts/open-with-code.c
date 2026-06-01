#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    
    const char *path = argv[1];
    char target[4096] = {0};
    
    // Check if it's a .desktop file
    size_t len = strlen(path);
    if (len > 8 && strcmp(path + len - 8, ".desktop") == 0) {
        FILE *f = fopen(path, "r");
        if (f) {
            char line[4096];
            while (fgets(line, sizeof(line), f)) {
                // Look for URL line (handles URL[$e]= too)
                if (strncmp(line, "URL", 3) == 0) {
                    char *eq = strchr(line, '=');
                    if (eq) {
                        char *url = eq + 1;
                        // Trim newline
                        url[strcspn(url, "\n")] = 0;
                        // Remove file:// prefix
                        if (strncmp(url, "file://", 7) == 0) {
                            url += 7;
                        } else if (strncmp(url, "file:", 5) == 0) {
                            url += 5;
                        }
                        // Expand $HOME
                        if (strncmp(url, "$HOME", 5) == 0) {
                            char *home = getenv("HOME");
                            if (home) {
                                snprintf(target, sizeof(target), "%s%s", home, url + 5);
                            }
                        } else {
                            strncpy(target, url, sizeof(target) - 1);
                        }
                    }
                    break;
                }
            }
            fclose(f);
        }
    }
    
    // If no target extracted, use original path
    if (target[0] == '\0') {
        strncpy(target, path, sizeof(target) - 1);
    }
    
    execlp("code", "code", target, NULL);
    return 1;
}
