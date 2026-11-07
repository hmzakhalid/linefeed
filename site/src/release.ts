/** Where the newest build lives; empty when the site is built outside GitHub. */
export const repositoryURL = __LINEFEED_REPOSITORY__;

export const downloadURL = repositoryURL
  ? `${repositoryURL}/releases/latest/download/Linefeed-macOS-arm64.dmg`
  : "#install";
