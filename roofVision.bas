DO UNTIL _SCREENEXISTS: LOOP
CLS: CLOSE
_ACCEPTFILEDROP ON
$RESIZE:ON
REM $DYNAMIC

TYPE mouse
    AS _BYTE left, right, middle, leftrelease, rightrelease, middlerelease
    AS INTEGER scroll, x, y
    AS _FLOAT noMovement, movementTimer, lefttime, righttime, middletime, lefttimedif, righttimedif, middletimedif, lefttimedif2, offsetx, offsety
END TYPE
REDIM SHARED mouse AS mouse
REDIM SHARED keyhit AS INTEGER

TYPE pixel
    AS _UNSIGNED _BYTE R, G, B, A
END TYPE
REDIM SHARED AS pixel originalImageArray(0, 0), segmentedImageArray(0, 0), testImageArrayR(0, 0), testImageArrayG(0, 0), testImageArrayB(0, 0), testImageArrayA(0, 0)
REDIM SHARED AS LONG originalImage, segmentedImage, testImage(4)
REDIM SHARED AS _BYTE imageLoaded, imageHasChanged, imageProcessed

SCREEN _NEWIMAGE(1920, 1080, 32)

'$INCLUDE: 'dependencies/opensave.bi'
'$INCLUDE: 'dependencies/saveimage.bi'

'--------------------------------------------------------------------------------------------------------------------------------------'

DO
    doChecks
    displayAll
LOOP

SUB displayImages
    displayImage originalImage, 0.5, 0, 0
    sW = getDisplayWidth(originalImage, 0.5, 0, 0)
    sH = getDisplayHeight(originalImage, 0.5, 0, 0)
    displayImage segmentedImage, 0.5, 0, sH
    'displayImage testImage(1), 1 / 4, sW + 1, 0
    'displayImage testImage(2), 1 / 4, sW * 1.5, 0
    'displayImage testImage(3), 1 / 4, sW + 1, sH * 0.5
    IF NOT imageLoaded THEN
        _PRINTSTRING (sW + 10, sH + 10), "Please drop an image to get started..."
    ELSEIF NOT imageProcessed AND imageLoaded THEN
        _PRINTSTRING (sW + 10, sH + 10), "Please press enter to process image..."
    ELSEIF imageProcessed AND imageLoaded THEN
        _PRINTSTRING (sW + 10, sH + 10), "Image successfully processed and saved!"
    END IF
END SUB

SUB keyboardCheck
    keyhit = _KEYHIT
    SELECT CASE keyhit
        CASE 13 'ENTER
            parseToSegmented originalImageArray(), segmentedImageArray(), 1
            parseArrayToImage segmentedImageArray(), segmentedImage
            success = SaveImage("export.png", segmentedImage, 0, 0, _WIDTH(segmentedImage) - 1, _HEIGHT(segmentedImage) - 1)
            'IF imageHasChanged THEN
            '    parseToTest originalImageArray(), testImageArrayR(), testImageArrayG(), testImageArrayB(), testImageArrayA(), 1
            '    parseArrayToImage testImageArrayR(), testImage(1)
            '    parseArrayToImage testImageArrayG(), testImage(2)
            '    parseArrayToImage testImageArrayB(), testImage(3)
            'END IF
            imageHasChanged = 0
    END SELECT
END SUB

SUB parseToSegmented (inputArray() AS pixel, outputArray() AS pixel, scale)
    REDIM outputArray(UBOUND(inputArray, 1), UBOUND(inputArray, 2)) AS pixel
    radius = 1
    treshhold = 100
    IF _FILEEXISTS("config.txt") THEN
        freen = FREEFILE
        OPEN "config.txt" FOR INPUT AS #freen
        INPUT #freen, radius
        INPUT #freen, treshhold
        CLOSE #freen
    END IF
    $CHECKING:OFF
    DO: x = x + 1
        y = 0: DO: y = y + 1
            newR = 0: newG = 0: newB = 0: newA = 0
            rDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "R")
            gDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "G")
            bDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "B")
            'aDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "A")
            IF 0.7152 * rDeviation + 0.2126 * gDeviation + 0.0722 * bDeviation < treshhold AND inputArray(x, y).R > treshhold AND inputArray(x, y).G <> 255 AND inputArray(x, y).B <> 255 AND inputArray(x, y).G < inputArray(x, y).R AND inputArray(x, y).B < inputArray(x, y).R THEN
                'IF rDeviation + gDeviation + bDeviation > treshhold THEN
                newR = 255
                newG = 255
                newB = 255
                newA = 255
                setArrayElem outputArray(), x, y, newB, newG, newR, newA
                'setArrayElem outputArray(), x + 1, y, newB, newG, newR, newA
                'setArrayElem outputArray(), x, y + 1, newB, newG, newR, newA
                'setArrayElem outputArray(), x + 1, y + 1, newB, newG, newR, newA
            ELSE
                setArrayElem outputArray(), x, y, 0, 0, 0, 0
            END IF
        LOOP UNTIL y >= UBOUND(inputArray, 2)
        LINE (0, 0)-(_WIDTH(0) * (x / UBOUND(inputArray, 1)), 5), _RGBA(255, 255, 255, 255), BF
        _DISPLAY
    LOOP UNTIL x >= UBOUND(inputArray, 1)
    $CHECKING:ON
END SUB

SUB parseToTest (inputArray() AS pixel, outputR() AS pixel, outputG() AS pixel, outputB() AS pixel, outputA() AS pixel, testImg)
    xSize = UBOUND(inputArray, 1)
    ySize = UBOUND(inputArray, 2)
    REDIM AS pixel outputR(xSize, ySize), outputG(xSize, ySize), outputB(xSize, ySize), outputA(xSize, ySize)
    radius = 1
    treshhold = 100
    IF _FILEEXISTS("config.txt") THEN
        freen = FREEFILE
        OPEN "config.txt" FOR INPUT AS #freen
        INPUT #freen, radius
        INPUT #freen, treshhold
        CLOSE #freen
    END IF
    $CHECKING:OFF
    DO: x = x + 1
        y = 0: DO: y = y + 1
            newR = 0: newG = 0: newB = 0: newA = 0
            rDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "R")
            gDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "G")
            bDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "B")
            'aDeviation = deviationFromSurroundingPixels(inputArray(), x, y, radius, "A")
            setArrayElem outputR(), x, y, rDeviation, 0, 0, 255
            setArrayElem outputG(), x, y, 0, gDeviation, 0, 255
            setArrayElem outputB(), x, y, 0, 0, bDeviation, 255
            'setArrayElem outputA(), x, y, 255, 255, 255, aDeviation
        LOOP UNTIL y >= UBOUND(inputArray, 2)
        LINE (0, 0)-(_WIDTH(0) * (x / UBOUND(inputArray, 1)), 5), _RGBA(150, 150, 150, 255), BF
        _DISPLAY
    LOOP UNTIL x >= UBOUND(inputArray, 1)
    $CHECKING:ON
END SUB

SUB setArrayElem (array() AS pixel, x, y, B, G, R, A)
    IF x > UBOUND(array, 1) OR y > UBOUND(array, 2) OR x < 1 OR y < 1 THEN EXIT SUB
    array(x, y).B = B
    array(x, y).G = G
    array(x, y).R = R
    array(x, y).A = A
END SUB

FUNCTION deviationFromSurroundingPixels (array() AS pixel, x, y, radius, property AS STRING)
    x2 = x - radius: DO
        y2 = y - radius: DO
            IF x2 > 0 AND y2 > 0 AND x2 < UBOUND(array, 1) AND y2 < UBOUND(array, 2) AND NOT (x2 = x AND y2 = y) THEN
                deviation = deviation + pixelDeviation(array(x, y), array(x2, y2), property)
                count = count + 1
            END IF
        y2 = y2 + 1: LOOP UNTIL y2 = y + radius
    x2 = x2 + 1: LOOP UNTIL x2 = x + radius
    deviationFromSurroundingPixels = INT(deviation / count)
END FUNCTION

FUNCTION pixelDeviation (pixel1 AS pixel, pixel2 AS pixel, property AS STRING)
    IF property = "R" THEN deviation = pixel2.R - pixel1.R
    IF property = "G" THEN deviation = pixel2.G - pixel1.G
    IF property = "B" THEN deviation = pixel2.B - pixel1.B
    IF property = "A" THEN deviation = pixel2.A - pixel1.A
    IF deviation < 0 THEN deviation = -deviation
    pixelDeviation = deviation
END FUNCTION

FUNCTION getDisplayWidth (image AS LONG, imageScale, xOffset, yOffset)
    winRatio = _WIDTH(0) / _HEIGHT(0)
    imgRatio = _WIDTH(image) / _HEIGHT(image)
    IF winRatio >= imgRatio THEN
        heightScaled = _HEIGHT(0)
        widthScaled = (_HEIGHT(0) / _HEIGHT(image)) * _WIDTH(image)
    ELSE
        widthScaled = _WIDTH(0)
        heightScaled = (_WIDTH(0) / _WIDTH(image)) * _HEIGHT(image)
    END IF
    getDisplayWidth = widthScaled * imageScale + xOffset
END FUNCTION

FUNCTION getDisplayHeight (image AS LONG, imageScale, xOffset, yOffset)
    winRatio = _WIDTH(0) / _HEIGHT(0)
    imgRatio = _WIDTH(image) / _HEIGHT(image)
    IF winRatio >= imgRatio THEN
        heightScaled = _HEIGHT(0)
        widthScaled = (_HEIGHT(0) / _HEIGHT(image)) * _WIDTH(image)
    ELSE
        widthScaled = _WIDTH(0)
        heightScaled = (_WIDTH(0) / _WIDTH(image)) * _HEIGHT(image)
    END IF
    getDisplayHeight = heightScaled * imageScale + yOffset
END FUNCTION

SUB displayImage (image AS LONG, imageScale, xOffset, yOffset)
    IF image > -2 THEN imageLoaded = 0: EXIT SUB
    winRatio = _WIDTH(0) / _HEIGHT(0)
    imgRatio = _WIDTH(image) / _HEIGHT(image)
    IF winRatio >= imgRatio THEN
        heightScaled = _HEIGHT(0)
        widthScaled = (_HEIGHT(0) / _HEIGHT(image)) * _WIDTH(image)
    ELSE
        widthScaled = _WIDTH(0)
        heightScaled = (_WIDTH(0) / _WIDTH(image)) * _HEIGHT(image)
    END IF
    LINE (xOffset, yOffset)-(widthScaled * imageScale + xOffset, heightScaled * imageScale + yOffset), _RGBA(255, 255, 255, 255), B
    _PUTIMAGE (xOffset, yOffset)-(widthScaled * imageScale + xOffset, heightScaled * imageScale + yOffset), image
    imageLoaded = -1
END SUB

SUB parseArrayToImage (array() AS pixel, Image AS LONG)
    IF Image > -2 THEN EXIT SUB
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(Image) 'Get a memory reference to our image
    DIM O AS _OFFSET, O_Last AS _OFFSET
    O = Buffer.OFFSET 'start at this offset
    maxx = _WIDTH(Image)
    maxy = _HEIGHT(Image)
    pixelCount = maxx * maxy
    O_Last = Buffer.OFFSET + pixelCount * 4 'We stop when we get to this offset
    $CHECKING:OFF
    DO
        p = p + 1
        y = FIX((p / pixelCount) * maxy)
        x = p - (FIX((p / pixelCount) * maxy) * maxx)
        _MEMPUT Buffer, O, array(x, y).B
        _MEMPUT Buffer, O + 1, array(x, y).G
        _MEMPUT Buffer, O + 2, array(x, y).R
        _MEMPUT Buffer, O + 3, array(x, y).A
        O = O + 4
    LOOP UNTIL O = O_Last
    $CHECKING:ON
    _MEMFREE Buffer
END SUB

SUB parseImageToArray (Image AS LONG, array() AS pixel, scale)
    bufferImg = _NEWIMAGE(_WIDTH(Image), _HEIGHT(Image), 32)
    _PUTIMAGE (0, 0)-(_WIDTH(bufferImg), _HEIGHT(bufferImg)), Image, bufferImg
    IF bufferImg > -2 THEN EXIT SUB
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(bufferImg) 'Get a memory reference to our image
    DIM O AS _OFFSET, O_Last AS _OFFSET
    O = Buffer.OFFSET 'start at this offset
    maxx = _WIDTH(bufferImg)
    maxy = _HEIGHT(bufferImg)
    pixelCount = maxx * maxy
    O_Last = Buffer.OFFSET + pixelCount * 4 'We stop when we get to this offset
    REDIM array(maxx, maxy) AS pixel
    $CHECKING:OFF
    DO
        p = p + 1
        y = FIX((p / pixelCount) * maxy)
        x = p - (FIX((p / pixelCount) * maxy) * maxx)
        array(x, y).B = _MEMGET(Buffer, O, _UNSIGNED _BYTE)
        array(x, y).G = _MEMGET(Buffer, O + 1, _UNSIGNED _BYTE)
        array(x, y).R = _MEMGET(Buffer, O + 2, _UNSIGNED _BYTE)
        array(x, y).A = _MEMGET(Buffer, O + 3, _UNSIGNED _BYTE)
        O = O + 4
    LOOP UNTIL O = O_Last
    $CHECKING:ON
    _MEMFREE Buffer
END SUB

SUB createSegmentedImage (Image AS LONG, imageSegments())
    IF R < 0 OR R > 1 OR G < 0 OR G > 1 OR B < 0 OR B > 1 OR _PIXELSIZE(Image) <> 4 THEN EXIT SUB
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(Image) 'Get a memory reference to our image

    'Used to avoid slow floating point calculations
    DIM AS LONG R_Frac, G_Frac, B_Frac, A_Frac
    R_Frac = R * 65536
    G_Frac = G * 65536
    B_Frac = B * 65536
    A_Frac = A * 65536

    DIM O AS _OFFSET, O_Last AS _OFFSET
    O = Buffer.OFFSET 'We start at this offset
    O_Last = Buffer.OFFSET + _WIDTH(Image) * _HEIGHT(Image) * 4 'We stop when we get to this offset
    'use on error free code ONLY!
    $CHECKING:OFF
    DO
        _MEMPUT Buffer, O, (_MEMGET(Buffer, O, _UNSIGNED _BYTE) * B_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 1, (_MEMGET(Buffer, O + 1, _UNSIGNED _BYTE) * G_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 2, (_MEMGET(Buffer, O + 2, _UNSIGNED _BYTE) * R_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 3, (_MEMGET(Buffer, O + 3, _UNSIGNED _BYTE) * A_Frac) \ 65536 AS _UNSIGNED _BYTE
        O = O + 4
    LOOP UNTIL O = O_Last
    'turn checking back on when done!
    $CHECKING:ON
    _MEMFREE Buffer
END SUB

SUB openFile (filename AS STRING)
    IF _FILEEXISTS(filename) THEN
        originalImage = _LOADIMAGE(filename, 32)
        IF originalImage < -1 THEN
            scale = 1
            parseImageToArray originalImage, originalImageArray(), scale
            segmentedImage = _NEWIMAGE(_WIDTH(originalImage), _HEIGHT(originalImage), 32)
            testImage(1) = _NEWIMAGE(_WIDTH(originalImage), _HEIGHT(originalImage), 32)
            testImage(2) = _NEWIMAGE(_WIDTH(originalImage), _HEIGHT(originalImage), 32)
            testImage(3) = _NEWIMAGE(_WIDTH(originalImage), _HEIGHT(originalImage), 32)
            testImage(4) = _NEWIMAGE(_WIDTH(originalImage), _HEIGHT(originalImage), 32)
            parseImageToArray segmentedImage, segmentedImageArray(), scale
            _PUTIMAGE (0, 0)-(_WIDTH(segmentedImage), _HEIGHT(segmentedImage)), originalImage, segmentedImage
            imageHasChanged = -1
        END IF
    END IF
END SUB

SUB fileDropCheck
    IF _TOTALDROPPEDFILES > 0 THEN
        REDIM img AS LONG
        DO
            df$ = _DROPPEDFILE
            IF _FILEEXISTS(df$) THEN
                droptype$ = "file"
            ELSE
                IF _DIREXISTS(a$) THEN
                    droptype$ = "folder"
                ELSE
                    droptype$ = "empty"
                END IF
            END IF
            SELECT CASE droptype$
                CASE "file"
                    openFile df$
            END SELECT
        LOOP UNTIL _TOTALDROPPEDFILES = 0
        _FINISHDROP
    END IF
END SUB

SUB mouseCheck
    mouse.scroll = 0
    startx = mouse.x
    starty = mouse.y
    DO
        mouse.x = _MOUSEX
        mouse.y = _MOUSEY
        mouse.offsetx = mouse.x - startx
        mouse.offsety = mouse.y - starty

        mouse.scroll = mouse.scroll + _MOUSEWHEEL

        mouse.left = _MOUSEBUTTON(1)
        IF mouse.left AND NOT invoke.ignoremouse THEN
            mouse.lefttimedif2 = mouse.lefttimedif
            mouse.lefttimedif = TIMER - mouse.lefttime: mouse.lefttime = TIMER
            IF mouse.leftrelease THEN
                mouse.leftrelease = 0
            END IF
        ELSE
            mouse.leftrelease = -1
            global.actionlock = 0
            lockmouse = 0
        END IF

        mouse.right = _MOUSEBUTTON(2)
        IF mouse.right AND NOT invoke.ignoremouse THEN
            IF mouse.rightrelease THEN
                mouse.rightrelease = 0
                mouse.righttimedif = TIMER - mouse.righttime: mouse.righttime = TIMER
            END IF
        ELSE
            mouse.rightrelease = -1
        END IF

        mouse.middle = _MOUSEBUTTON(3)
        IF mouse.middle AND NOT invoke.ignoremouse THEN
            IF mouse.middlerelease THEN
                mouse.middlerelease = 0
                mouse.middletimedif = TIMER - mouse.middletime: mouse.middletime = TIMER
            END IF
        ELSE
            mouse.rightrelease = -1
        END IF
    LOOP WHILE _MOUSEINPUT
    IF mouse.right = 0 THEN activeHandleGrab = 0
    IF mouse.left = 0 THEN activeGrab = 0
    IF mouse.x = startx AND mouse.y = starty THEN
        IF mouse.noMovement < mouse.movementTimer + 1000 THEN mouse.noMovement = mouse.noMovement + 1
    ELSE
        mouse.noMovement = 0
    END IF
    IF mouse.left OR mouse.right OR mouse.middle THEN mouse.noMovement = 0
END SUB

SUB displayAll
    CLS
    displayImages
    _DISPLAY
END SUB

SUB doChecks
    checkResize
    fileDropCheck
    mouseCheck
    keyboardCheck
END SUB

SUB checkResize
    IF _RESIZE THEN
        DO
            winresx = _RESIZEWIDTH
            winresy = _RESIZEHEIGHT
        LOOP WHILE _RESIZE
        IF (winresx <> _WIDTH(0) OR winresy <> _HEIGHT(0)) THEN
            setWindow winresx, winresy
        END IF
    END IF
END SUB

SUB setWindow (winresx AS INTEGER, winresy AS INTEGER)
    SCREEN _NEWIMAGE(winresx, winresy, 32)
    DO: LOOP UNTIL _SCREENEXISTS
    'screenresx = _DESKTOPWIDTH
    'screenresy = _DESKTOPHEIGHT
    '_SCREENMOVE (screenresx / 2) - (winresx / 2), (screenresy / 2) - (winresy / 2)
END SUB

FUNCTION min (a, b)
    IF a < b THEN min = a ELSE min = b
END FUNCTION

FUNCTION max (a, b)
    IF a > b THEN max = a ELSE max = b
END FUNCTION

FUNCTION maxArray (array())
    IF UBOUND(array) < 1 THEN EXIT FUNCTION
    DO: i = i + 1
        IF array(i) > maxBuffer THEN maxBuffer = array(i)
    LOOP UNTIL i = UBOUND(array)
    maxArray = maxBuffer
END FUNCTION

FUNCTION ctrlDown
    IF _KEYDOWN(100305) OR _KEYDOWN(100306) THEN ctrlDown = -1 ELSE ctrlDown = 0
END FUNCTION

FUNCTION shiftDown
    IF _KEYDOWN(100303) OR _KEYDOWN(100304) THEN shiftDown = -1 ELSE shiftDown = 0
END FUNCTION

FUNCTION altDown
    IF _KEYDOWN(100308) OR _KEYDOWN(100307) THEN altDown = -1 ELSE altDown = 0
END FUNCTION

'--------------------------------------------------------------------------------------------------------------------------------------'

'$INCLUDE: 'dependencies/saveimage.bm'
'$INCLUDE: 'dependencies/opensave.bm'

