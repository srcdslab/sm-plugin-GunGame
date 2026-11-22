#if defined _gungame_url_included_
  #endinput
#endif
#define _gungame_url_included_

/**
 * URL-encodes a string (spaces become '+').
 *
 * @param strFrom       Source string.
 * @param lenFrom       Size of the source string.
 * @param strTo         Output buffer.
 * @param lenTo         Size of the output buffer.
 */
stock void url_encode(const char[] strFrom, int lenFrom, char[] strTo, int lenTo)
{
    static const char hexchars[] = "0123456789ABCDEF";
    int c;
    int to = 0, from = 0;

    while ( from < lenFrom && to < lenTo - 3 ) {
        c = strFrom[from++];
        if ( c == '\0' ) {
            break;
        } else if ( c == ' ' ) {
            strTo[to++] = '+';
        } else if ( IsCharAlpha(c) || IsCharNumeric(c) || ('_' == c) || ('-' == c) || ('.' == c) ) {
            strTo[to++] = c;
        } else {
            strTo[to++] = '%';
            strTo[to++] = hexchars[(c >> 4) & 15];
            strTo[to++] = hexchars[c & 15];
        }
    }
    strTo[to] = '\0';
}
