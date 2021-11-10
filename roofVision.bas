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
'REDIM SHARED AS pixel OGimgArr(0, 0, 0), segmentedImageArray(0, 0, 0), refImageArray(0, 0, 0)
REDIM SHARED AS LONG originalImages(0), segmentedImages(0), refImages(0)
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
    IF UBOUND(originalImages) > 0 THEN
        iW = _WIDTH(0) / UBOUND(originalImages)
        DO: i = i + 1
            displayImage originalImages(i), iW / _WIDTH(originalImages(i)), (i - 1) * iW, 0
        LOOP UNTIL i = UBOUND(originalImages)

        iW = _WIDTH(0) / UBOUND(segmentedImages)
        i = 0: DO: i = i + 1
            displayImage segmentedImages(i), iW / _WIDTH(segmentedImages(i)), (i - 1) * iW, _HEIGHT(0) / 2
        LOOP UNTIL i = UBOUND(originalImages)

        iW = _WIDTH(0) / UBOUND(refImages)
        i = 0: DO: i = i + 1
            displayImage refImages(i), iW / _WIDTH(refImages(i)), (i - 1) * iW, _HEIGHT(0) / 2
        LOOP UNTIL i = UBOUND(originalImages)
    END IF

    tY = _HEIGHT(0) - _FONTHEIGHT - 10
    IF NOT imageLoaded THEN
        _PRINTSTRING (10, tY), "Please drop an image to get started..."
    ELSEIF NOT imageProcessed AND imageLoaded THEN
        _PRINTSTRING (10, tY), "Please press enter to process image..."
    ELSEIF imageProcessed AND imageLoaded THEN
        _PRINTSTRING (10, tY), "Image successfully processed and saved!"
    END IF
END SUB

SUB keyboardCheck
    keyhit = _KEYHIT
    SELECT CASE keyhit
        CASE 13 'ENTER
            DO: i = i + 1
                parseToSegmented originalImages(i), refImages(i), segmentedImages(i), 1
                success = SaveImage("export" + LTRIM$(STR$(i)) + ".bmp", segmentedImages(i), 0, 0, _WIDTH(segmentedImages(i)) - 1, _HEIGHT(segmentedImages(i)) - 1)

                displayAll ' be a little nice and view images that have been converted so far
            LOOP UNTIL i = UBOUND(originalImages)
            imageHasChanged = 0
        CASE 27
            SYSTEM
    END SELECT
END SUB

SUB parseToSegmented (originalImage AS LONG, refImage AS LONG, outputImage AS LONG, scale)
    radius = 1
    treshhold = 100
    IF _FILEEXISTS("config.txt") THEN
        freen = FREEFILE
        OPEN "config.txt" FOR INPUT AS #freen
        INPUT #freen, mode
        INPUT #freen, radius
        INPUT #freen, treshhold
        INPUT #freen, treshholdR
        INPUT #freen, neighborTreshhold
        INPUT #freen, referenceImage$
        CLOSE #freen
    END IF
    surroundingPixelArea = (((radius * 2) + 1) ^ 2) - 1

    REDIM AS pixel OGimgArr(0, 0), outputImgArray(0, 0), refImageArray(0, 0)
    parseImageToArray originalImage, OGimgArr()
    parseImageToArray outputImage, outputImgArray()
    parseImageToArray refImage, refImageArray()

    $CHECKING:OFF
    ' remove all pixels that don't meet the overcomplicated conditions
    DO: x = x + 1
        y = 0: DO: y = y + 1
            newR = 0: newG = 0: newB = 0: newA = 0
            SELECT CASE mode
                CASE 1 ' extract roofs
                    IF refImageArray(x, y).R > 0 OR refImageArray(x, y).G > 0 OR refImageArray(x, y).B > 0 THEN
                        setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                    END IF
                CASE 2 ' find roof areas
                    rDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "R")
                    gDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "G")
                    bDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "B")
                    aDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "A")
                    IF (0.7152 * rDeviation) + (0.2126 * gDeviation) + (0.0722 * bDeviation) < treshhold AND OGimgArr(x, y).R > treshholdR THEN
                        IF ((OGimgArr(x, y).G < OGimgArr(x, y).R - 20 AND OGimgArr(x, y).B < OGimgArr(x, y).R - 20) OR (OGimgArr(x, y).B > OGimgArr(x, y).G - 10 AND OGimgArr(x, y).B < OGimgArr(x, y).G + 10) AND OGimgArr(x, y).B < OGimgArr(x, y).R AND OGimgArr(x, y).G < OGimgArr(x, y).R) THEN
                            IF OGimgArr(x, y).R < 255 OR OGimgArr(x, y).G < 255 OR OGimgArr(x, y).B < 255 THEN
                                setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                            END IF
                        ELSE
                            setArrayElem outputImgArray(), x, y, 0, 0, 0, 0
                        END IF
                    END IF
                CASE 3 ' erase lonely pixels
                    ' create buffer array to not overwrite output
                    REDIM bufferArray(UBOUND(outputImgArray, 1), UBOUND(outputImgArray, 2)) AS pixel
                    x = 0: DO: x = x + 1
                        y = 0: DO: y = y + 1
                            setArrayElem bufferArray(), x, y, outputImgArray(x, y).B, outputImgArray(x, y).G, outputImgArray(x, y).R, outputImgArray(x, y).A
                        LOOP UNTIL y >= UBOUND(outputImgArray, 2)
                    LOOP UNTIL x >= UBOUND(outputImgArray, 1)

                    ' remove pixels that have less than x filled neighbors
                    x = 0: DO: x = x + 1
                        y = 0: DO: y = y + 1
                            newR = 0: newG = 0: newB = 0: newA = 0
                            filledNeighbors = getFilledNeighborsAmount(outputImgArray(), x, y, radius, surroundingPixelArea)
                            IF filledNeighbors > neighborTreshhold THEN
                                setArrayElem bufferArray(), x, y, outputImgArray(x, y).B, outputImgArray(x, y).G, outputImgArray(x, y).R, 255
                            ELSE
                                setArrayElem bufferArray(), x, y, 0, 0, 0, 0
                            END IF
                        LOOP UNTIL y >= UBOUND(outputImgArray, 2)
                        LINE (0, 0)-(_WIDTH(0) * (x / UBOUND(outputImgArray, 1)), 5), _RGBA(0, 255, 255, 255), BF
                        _DISPLAY
                    LOOP UNTIL x >= UBOUND(outputImgArray, 1)

                    ' swap buffer array with output
                    x = 0: DO: x = x + 1
                        y = 0: DO: y = y + 1
                            SWAP outputImgArray(x, y), bufferArray(x, y)
                        LOOP UNTIL y >= UBOUND(outputImgArray, 2)
                    LOOP UNTIL x >= UBOUND(outputImgArray, 1)
            END SELECT
        LOOP UNTIL y >= UBOUND(OGimgArr, 2)
        LINE (0, 0)-(_WIDTH(0) * (x / UBOUND(OGimgArr, 1)), 5), _RGBA(255, 255, 255, 255), BF
        _DISPLAY
    LOOP UNTIL x >= UBOUND(OGimgArr, 1)

    parseArrayToImage outputImgArray(), outputImage
    $CHECKING:ON
END SUB

FUNCTION getFilledNeighborsAmount (array() AS pixel, x, y, radius, surroundingPixelArea)
    x2 = x - radius: DO
        y2 = y - radius: DO
            IF x2 > 0 AND y2 > 0 AND x2 < UBOUND(array, 1) AND y2 < UBOUND(array, 2) AND NOT (x2 = x AND y2 = y) THEN
                IF array(x2, y2).A > 0 THEN
                    count = count + 1
                END IF
            END IF
        y2 = y2 + 1: LOOP UNTIL y2 = y + radius
    x2 = x2 + 1: LOOP UNTIL x2 = x + radius
    getFilledNeighborsAmount = count / surroundingPixelArea
END FUNCTION

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

SUB parseImageToArray (Image AS LONG, array() AS pixel)
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
            PRINT "Importing image... (This may take a while for big images)"
            _DISPLAY

            IF UBOUND(originalImages) > 0 THEN
                DO: i = i + 1
                    IF originalImages(i) < -1 THEN _FREEIMAGE originalImages(i)
                    IF segmentedImages(i) < -1 THEN _FREEIMAGE segmentedImages(i)
                    IF refImages(i) < -1 THEN _FREEIMAGE refImages(i)
                LOOP UNTIL i = UBOUND(originalImages)
            END IF
            REDIM _PRESERVE AS LONG originalImages(0), segmentedImages(0), refImages(0), refImage
            IF _FILEEXISTS("config.txt") THEN
                freen = FREEFILE
                OPEN "config.txt" FOR INPUT AS #freen
                INPUT #freen, mode
                INPUT #freen, radius
                INPUT #freen, treshhold
                INPUT #freen, treshholdR
                INPUT #freen, neighborTreshhold
                INPUT #freen, referenceImage$
                CLOSE #freen
            END IF

            refImage = _LOADIMAGE(referenceImage$, 32)

            ' divide image into smaller tiles, creates one tile if image is smaller
            tileSize = 2000
            i = 0
            yOffset = 0: DO
                xOffset = 0: DO
                    i = i + 1
                    REDIM _PRESERVE AS LONG originalImages(i), segmentedImages(i), refImages(i)
                    originalImages(i) = _NEWIMAGE(tileSize, tileSize, 32)
                    _PUTIMAGE (-xOffset, -yOffset)-(-xOffset + _WIDTH(originalImage), -yOffset + _HEIGHT(originalImage)), originalImage, originalImages(i)

                    segmentedImages(i) = _NEWIMAGE(tileSize, tileSize, 32)
                    _PUTIMAGE (-xOffset, -yOffset)-(-xOffset + _WIDTH(refImage), -yOffset + _HEIGHT(refImage)), refImage, segmentedImages(i)

                    refImages(i) = _NEWIMAGE(tileSize, tileSize, 32)
                    _PUTIMAGE (-xOffset, -yOffset)-(-xOffset + _WIDTH(refImage), -yOffset + _HEIGHT(refImage)), refImage, refImages(i)
                xOffset = xOffset + tileSize: LOOP UNTIL xOffset >= _WIDTH(originalImage)
            yOffset = yOffset + tileSize: LOOP UNTIL yOffset >= _HEIGHT(originalImage)

            _FREEIMAGE originalImage

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

