b = bytearray(open('fontbin', 'rb').read())
for i in range(len(b)):
    b[i] ^= 0xFF
open('flipfont', 'wb').write(b)