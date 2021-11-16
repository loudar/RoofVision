DO UNTIL _SCREENEXISTS: LOOP
CLS: CLOSE
_ACCEPTFILEDROP ON
$RESIZE:ON
REM $DYNAMIC
'$CHECKING:OFF

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
TYPE rectangle
    AS INTEGER x, y, w, h
END TYPE
TYPE groupPoint
    AS INTEGER group
    AS LONG colour
END TYPE
TYPE point
    AS INTEGER x, y
END TYPE
'REDIM SHARED AS pixel OGimgArr(0, 0, 0), segmentedImageArray(0, 0, 0), refImageArray(0, 0, 0)
REDIM SHARED AS LONG originalImages(0), segmentedImages(0), refImages(0), originalImage, refImage
REDIM SHARED AS _BYTE imageProcessed, originalImageLoaded, referenceImageLoaded
REDIM SHARED AS INTEGER tileSize
REDIM SHARED AS _UNSIGNED _INTEGER64 lastGroup
tileSize = 2000

SCREEN _NEWIMAGE(1920, 1080, 32)
_TITLE "RoofVision"
RANDOMIZE TIMER

TYPE settings
    AS INTEGER modeOffset, radius, treshhold, neighborTreshhold
    AS STRING outputFolder
END TYPE
REDIM SHARED AS settings settings
loadSettings

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
        i = 0: DO: i = i + 1
            displayImage originalImages(i), iW / _WIDTH(originalImages(i)), (i - 1) * iW, 0
        LOOP UNTIL i = UBOUND(originalImages)

        iW = _WIDTH(0) / UBOUND(segmentedImages)
        i = 0: DO: i = i + 1
            displayImage segmentedImages(i), iW / _WIDTH(segmentedImages(i)), (i - 1) * iW, _HEIGHT(0) / 2
        LOOP UNTIL i = UBOUND(segmentedImages)
        IF NOT imageProcessed THEN
            IF mode = 1 THEN
                iW = _WIDTH(0) / UBOUND(refImages)
                i = 0: DO: i = i + 1
                    displayImage refImages(i), iW / _WIDTH(refImages(i)), (i - 1) * iW, _HEIGHT(0) / 2
                LOOP UNTIL i = UBOUND(originalImages)
                'ELSE
                '    iW = _WIDTH(0) / UBOUND(originalImages)
                '    i = 0: DO: i = i + 1
                '        displayImage originalImages(i), iW / _WIDTH(originalImages(i)), (i - 1) * iW, 0
                '    LOOP UNTIL i = UBOUND(originalImages)
            END IF
        END IF
    END IF

    margin = 20
    IF NOT originalImageLoaded THEN
        LINE (margin, margin)-((_WIDTH(0) / 2) - margin, _HEIGHT(0) - margin), col&("yellow"), B
    END IF
    IF NOT referenceImageLoaded THEN
        LINE ((_WIDTH(0) / 2) + margin, margin)-(_WIDTH(0) - margin, _HEIGHT(0) - margin), col&("yellow"), B
    END IF

    tY = _HEIGHT(0) - _FONTHEIGHT - 10
    IF originalImageLoaded THEN COLOR col&("green"): status$ = "OK" ELSE COLOR col&("red"): status$ = "NOT OK"
    _PRINTSTRING (10, tY - _FONTHEIGHT), "Source image " + status$
    IF referenceImageLoaded THEN COLOR col&("green"): status$ = "OK" ELSE COLOR col&("red"): status$ = "NOT OK"
    _PRINTSTRING (10, tY - (_FONTHEIGHT * 2)), "Reference image " + status$
    COLOR col&("white")

    IF NOT originalImageLoaded OR NOT referenceImageLoaded THEN
        _PRINTSTRING (10, tY), "Please drop an image to get started..."
    ELSEIF NOT imageProcessed THEN
        _PRINTSTRING (10, tY), "Please press enter to process image..."
    ELSEIF imageProcessed THEN
        _PRINTSTRING (10, tY), "Image successfully processed and saved!"
    END IF
END SUB

FUNCTION col& (colour AS STRING)
    SELECT CASE colour
        CASE "green"
            col& = _RGBA(50, 255, 0, 255)
        CASE "yellow"
            col& = _RGBA(255, 230, 0, 255)
        CASE "red"
            col& = _RGBA(255, 50, 0, 255)
        CASE "white"
            col& = _RGBA(255, 255, 255, 255)
        CASE "black"
            col& = _RGBA(0, 0, 0, 255)
        CASE "transparent"
            col& = _RGBA(0, 0, 0, 0)
    END SELECT
END FUNCTION

SUB keyboardCheck
    keyhit = _KEYHIT
    SELECT CASE keyhit
        CASE 13 'ENTER
            processImages
        CASE 27
            SYSTEM
    END SELECT
END SUB

SUB processImages
    IF NOT _DIREXISTS(settings.outputFolder) THEN
        MKDIR settings.outputFolder
    END IF

    mode = settings.modeOffset: DO: mode = mode + 1
        IF mode = 2 AND refImage < -1 THEN mode = 3 ' skips automatic object detection if reference image is present
        DO: i = i + 1
            tY = _HEIGHT(0) - _FONTHEIGHT - 10
            _PRINTSTRING (10, tY), "Using mode " + LTRIM$(STR$(mode)) + "...                           "
            _PRINTSTRING (10, tY), "Processing tile " + LTRIM$(STR$(i)) + "...                           "
            _DISPLAY

            REDIM progCoord AS rectangle
            progCoord.w = (_WIDTH(0) / UBOUND(originalImages))
            progCoord.x = (i - 1) * progCoord.w
            progCoord.y = _HEIGHT(0) / 2
            progCoord.h = progCoord.w
            parseToSegmented originalImages(i), refImages(i), segmentedImages(i), 1, progCoord, mode, settings.radius, settings.treshhold, settings.neighborTreshhold
            success = SaveImage(settings.outputFolder + "export" + LTRIM$(STR$(i)) + ".png", segmentedImages(i), 0, 0, _WIDTH(segmentedImages(i)) - 1, _HEIGHT(segmentedImages(i)) - 1)

            displayAll ' be a little nice and view images that have been converted so far
        LOOP UNTIL i = UBOUND(originalImages)
        replaceImages originalImages(), segmentedImages(), -1
    LOOP UNTIL mode = 5
END SUB

SUB replaceImages (array1() AS LONG, array2() AS LONG, empty2 AS _BYTE)
    IF UBOUND(array1) <> UBOUND(array2) OR UBOUND(array1) < 1 OR UBOUND(array2) < 1 THEN EXIT SUB
    DO: i = i + 1
        array1(i) = _COPYIMAGE(array2(i), 32)
        IF empty2 THEN
            array2(i) = _NEWIMAGE(_WIDTH(array2(i)), _HEIGHT(array2(i)), 32)
        END IF
    LOOP UNTIL i = UBOUND(array1)
END SUB

SUB parseToSegmented (originalImage AS LONG, refImage AS LONG, outputImage AS LONG, scale, progCoord AS rectangle, mode, radius, treshhold, neighborTreshhold)
    surroundingPixelArea = (((radius * 2) + 1) ^ 2) - 1
    areaScale = 1 / ((2 * radius) + 1)

    REDIM AS pixel OGimgArr(0, 0), outputImgArray(0, 0), refImageArray(0, 0), downScaleArray(0, 0)
    IF mode = 3 THEN
        REDIM AS LONG downScaled
        downScaleW = _WIDTH(originalImage) * areaScale
        downScaleH = _HEIGHT(originalImage) * areaScale
        downScaled = _NEWIMAGE(downScaleW, downScaleH, 32)
        parseImageToArray downScaled, downScaleArray()
        _PUTIMAGE (0, 0)-(downScaleW, downScaleH), originalImage, downScaled
    END IF
    parseImageToArray originalImage, OGimgArr()
    pixelCount = UBOUND(OGimgArr, 1) * UBOUND(OGimgArr, 2)
    parseImageToArray outputImage, outputImgArray()
    IF mode = 1 THEN
        parseImageToArray refImage, refImageArray()
    END IF

    IF mode > 1 AND refImage < -1 THEN
        _FREEIMAGE refImage
    END IF
    IF mode = 4 THEN
        REDIM AS LONG fillImage
        fillImage = _COPYIMAGE(originalImage, 32)
    END IF
    LINE (progCoord.x, progCoord.y)-(progCoord.x + progCoord.w, progCoord.y + progCoord.h), _RGBA(255, 255, 0, 255), B
    _PRINTSTRING (progCoord.x + 3, progCoord.y - _FONTHEIGHT - 3), "Processing...": _DISPLAY
    _DELAY 1
    x = 0: DO
        y = 0: DO
            SELECT CASE mode
                CASE 1 ' extract roofs
                    IF refImageArray(x, y).R > 0 OR refImageArray(x, y).G > 0 OR refImageArray(x, y).B > 0 THEN
                        setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                    END IF
                CASE 2 ' find roof areas
                    rDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "R")
                    gDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "G")
                    bDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "B")
                    'aDeviation = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "A")
                    'IF (0.7152 * rDeviation) + (0.2126 * gDeviation) + (0.0722 * bDeviation) < treshhold AND OGimgArr(x, y).R > treshholdR THEN
                    '    IF ((OGimgArr(x, y).G < OGimgArr(x, y).R - 20 AND OGimgArr(x, y).B < OGimgArr(x, y).R - 20) OR (OGimgArr(x, y).B > OGimgArr(x, y).G - 10 AND OGimgArr(x, y).B < OGimgArr(x, y).G + 10) AND OGimgArr(x, y).B < OGimgArr(x, y).R AND OGimgArr(x, y).G < OGimgArr(x, y).R) THEN
                    '        IF OGimgArr(x, y).R < 255 OR OGimgArr(x, y).G < 255 OR OGimgArr(x, y).B < 255 THEN
                    '            setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                    '        END IF
                    '    ELSE
                    '        setArrayElem outputImgArray(), x, y, 0, 0, 0, 0
                    '    END IF
                    'END IF
                    IF (0.4 * rDeviation) + (0.4 * gDeviation) + (0.2 * bDeviation) < treshhold THEN
                        setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                    END IF
                CASE 3 ' find roof parts
                    IF OGimgArr(x, y).R = 0 AND OGimgArr(x, y).G = 0 AND OGimgArr(x, y).B = 0 THEN
                        setArrayElem outputImgArray(), x, y, 0, 0, 0, 0
                    ELSE
                        dSx = FIX(x * areaScale) + 1
                        dSy = FIX(y * areaScale) + 1
                        rDeviation = pixelDeviation(OGimgArr(x, y), downScaleArray(dSx, dSy), "R")
                        gDeviation = pixelDeviation(OGimgArr(x, y), downScaleArray(dSx, dSy), "G")
                        bDeviation = pixelDeviation(OGimgArr(x, y), downScaleArray(dSx, dSy), "B")
                        'aDeviation = pixelDeviation(OGimgArr(x, y), downScaleArray(dSx, dSy), "A")
                        rDeviation2 = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "R")
                        gDeviation2 = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "G")
                        bDeviation2 = deviationFromSurroundingPixels(OGimgArr(), x, y, radius, "B")
                        IF rDeviation + gDeviation + bDeviation < treshhold OR rDeviation2 + gDeviation2 + bDeviation2 < treshhold THEN
                            setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                        END IF
                        'IF (0.7152 * rDeviation) + (0.2126 * gDeviation) + (0.0722 * bDeviation) < treshhold AND OGimgArr(x, y).R > treshholdR THEN
                        '    IF ((OGimgArr(x, y).G < OGimgArr(x, y).R - 20 AND OGimgArr(x, y).B < OGimgArr(x, y).R - 20) OR (OGimgArr(x, y).B > OGimgArr(x, y).G - 10 AND OGimgArr(x, y).B < OGimgArr(x, y).G + 10) AND OGimgArr(x, y).B < OGimgArr(x, y).R AND OGimgArr(x, y).G < OGimgArr(x, y).R) THEN
                        '        IF OGimgArr(x, y).R < 255 OR OGimgArr(x, y).G < 255 OR OGimgArr(x, y).B < 255 THEN
                        '            setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                        '        END IF
                        '    ELSE
                        '        setArrayElem outputImgArray(), x, y, 0, 0, 0, 0
                        '    END IF
                        'END IF
                        'IF rDeviation + gDeviation + bDeviation < treshhold THEN
                        'setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                        'ELSE
                        '    setArrayElem outputImgArray(), x, y, 0, 0, 0, 0
                        'END IF
                    END IF
                CASE 4 ' divide into areas
                    y = y + 3
                    IF OGimgArr(x, y).R = 0 AND OGimgArr(x, y).G = 0 AND OGimgArr(x, y).B = 0 THEN
                    ELSE
                        _DEST fillImage
                        PAINT (x, y), getRandomColor~&, _RGBA(0, 0, 0, 255)
                        '    IF pixelGroups(x, y).group = 0 THEN
                        '        createPixelGroup OGimgArr(), x, y, pixelGroups()
                        '    END IF
                        '    checkAdjacentPixels OGimgArr(), x, y, pixelGroups()
                    END IF
                CASE 5 ' fill lonely empty pixels / works in tandem with method below
                    IF pixelIsSurrounded(OGimgArr(), x, y) THEN
                        setArrayElem outputImgArray(), x, y, OGimgArr(x, y).B, OGimgArr(x, y).G, OGimgArr(x, y).R, 255
                    ELSE
                        setArrayElem outputImgArray(), x, y, 0, 0, 0, 0
                    END IF
            END SELECT
        y = y + 1: LOOP UNTIL y >= UBOUND(OGimgArr, 2)
        IF _DEST <> 0 THEN _DEST 0
        _PRINTSTRING (progCoord.x + 3, progCoord.y - (2 * _FONTHEIGHT) - 3), "(" + LTRIM$(STR$(x * y)) + "/" + LTRIM$(STR$(pixelCount)) + ")"
        'LINE (progCoord.x, progCoord.y)-(progCoord.x + progCoord.w, progCoord.y + progCoord.h), _RGBA(255, 255, 0, 255), B
        IF mode = 4 THEN
            _PUTIMAGE (progCoord.x + 1, progCoord.y + 1)-(progCoord.x + progCoord.w - 1, progCoord.y + progCoord.h - 1), fillImage
        END IF
        LINE (progCoord.x + 1, progCoord.y + 1)-(progCoord.x + (progCoord.w * (x / UBOUND(OGimgArr, 1))) - 1, progCoord.y + progCoord.h - 1), _RGBA(255, 255, 0, 30), BF
        _DISPLAY
    x = x + 1: LOOP UNTIL x >= UBOUND(OGimgArr, 1)

    SELECT CASE mode
        CASE 4
            parseImageToArray fillImage, outputImgArray()
            'x = 0: DO
            '    y = 0: DO
            '        pixelColor = pixelGroups(x, y).colour
            '        setArrayElem outputImgArray(), x, y, _BLUE(pixelColor), _GREEN(pixelColor), _RED(pixelColor), 255
            '    y = y + 1: LOOP UNTIL y >= UBOUND(OGimgArr, 2)
            '    _PRINTSTRING (10 + progCoord.x, progCoord.y - (2 * _FONTHEIGHT) - 10), "(" + LTRIM$(STR$(x * y)) + "/" + LTRIM$(STR$(pixelCount)) + ")"
            '    LINE (progCoord.x, progCoord.y)-(progCoord.x + (progCoord.w * (x / UBOUND(OGimgArr, 1))), progCoord.y + progCoord.h), _RGBA(255, 220, 0, 255), BF
            '    _DISPLAY
            'x = x + 1: LOOP UNTIL x >= UBOUND(OGimgArr, 1)
        CASE 5 ' erase lonely filled pixels
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

    IF mode = 4 THEN
        REDIM AS groupPoint pixelGroups(0, 0)
        REDIM AS _BYTE checkedPixel(0, 0)
    END IF

    LINE (progCoord.x, progCoord.y)-(progCoord.x + progCoord.w, progCoord.y + progCoord.h), _RGBA(0, 255, 0, 255), BF
    _DISPLAY

    parseArrayToImage outputImgArray(), outputImage
    REDIM AS pixel OGimgArr(0, 0), outputImgArray(0, 0), refImageArray(0, 0), downScaleArray(0, 0)
END SUB

SUB loadSettings
    IF _FILEEXISTS("config.txt") THEN
        freen = FREEFILE
        OPEN "config.txt" FOR INPUT AS #freen
        INPUT #freen, settings$
        CLOSE #freen
        settings.modeOffset = getArgumentv(settings$, "modeOffset")
        settings.radius = getArgumentv(settings$, "radius")
        settings.treshhold = getArgumentv(settings$, "treshhold")
        settings.neighborTreshhold = getArgumentv(settings$, "neighborTreshhold")
        settings.outputFolder = getArgument$(settings$, "outputFolder")
        IF RIGHT$(settings.outputFolder, 1) <> "/" THEN settings.outputFolder = settings.outputFolder + "/"
    ELSE
        settings.modeOffset = 0
        settings.radius = 2
        settings.treshhold = 45
        settings.neighborTreshhold = 0.4
        settings.outputFolder = "export/"
    END IF
END SUB

FUNCTION getFreeGroup (x, y, pixelGroups() AS groupPoint)
    getFreeGroup = lastGroup + 1
END FUNCTION

FUNCTION getRandomColor~&
    getRandomColor~& = HSLtoRGB~&(RND * 360, 1, 1, 255)
END FUNCTION

SUB createPixelGroup (array() AS pixel, x, y, pixelGroups() AS groupPoint)
    IF array(x, y).R > 0 OR array(x, y).G > 0 OR array(x, y).B > 0 THEN
        lastGroup = getFreeGroup(x, y, pixelGroups())
        colour~& = getRandomColor~&
        setGroupPixel x, y, lastGroup, colour, pixelGroups()
    END IF
END SUB

SUB checkAdjacentPixels (array() AS pixel, x, y, pixelGroups() AS groupPoint)
    x2 = x - 1: DO
        y2 = y - 1: DO
            IF x2 < UBOUND(array, 1) AND y2 < UBOUND(array, 2) AND x2 > -1 AND y2 > -1 AND NOT (x = x2 AND y = y2) THEN
                IF pixelGroups(x, y).group > 0 AND pixelGroups(x2, y2).group = 0 AND (array(x2, y2).R > 0 OR array(x2, y2).G > 0 OR array(x2, y2).B > 0) THEN
                    setGroupPixel x2, y2, pixelGroups(x, y).group, pixelGroups(x, y).colour, pixelGroups()
                    'checkAdjacentPixels array(), x2, y2, pixelGroups()
                ELSEIF pixelGroups(x2, y2).group > 0 AND (array(x2, y2).R > 0 OR array(x2, y2).G > 0 OR array(x2, y2).B > 0) THEN
                    setGroupPixel x, y, pixelGroups(x2, y2).group, pixelGroups(x2, y2).colour, pixelGroups()
                END IF
            END IF
        y2 = y2 + 1: LOOP UNTIL y2 = y + 2
    x2 = x2 + 1: LOOP UNTIL x2 = x + 2
END SUB

FUNCTION pixelIsSurrounded (array() AS pixel, x, y)
    buffer = 0
    x2 = x - 1: DO
        y2 = y - 1: DO
            IF x2 < UBOUND(array, 1) AND y2 < UBOUND(array, 2) AND x2 > -1 AND y2 > -1 AND NOT (x = x2 AND y = y2) THEN
                IF array(x2, y2).R > 0 OR array(x2, y2).G > 0 OR array(x2, y2).B > 0 THEN
                    buffer = buffer + 1
                END IF
            END IF
        y2 = y2 + 1: LOOP UNTIL y2 = y + 2
    x2 = x2 + 1: LOOP UNTIL x2 = x + 2
    IF buffer > 7 THEN
        pixelIsSurrounded = -1
    ELSE
        pixelIsSurrounded = 0
    END IF
END FUNCTION

SUB setGroupPixel (x, y, group, colour AS LONG, pixelGroups() AS groupPoint)
    pixelGroups(x, y).group = group
    pixelGroups(x, y).colour = colour
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
    IF x > UBOUND(array, 1) OR y > UBOUND(array, 2) OR x < 0 OR y < 0 THEN EXIT SUB
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
    'winRatio = _WIDTH(0) / _HEIGHT(0)
    'imgRatio = _WIDTH(image) / _HEIGHT(image)
    'IF winRatio >= imgRatio THEN
    '    heightScaled = _HEIGHT(0)
    '    widthScaled = (_HEIGHT(0) / _HEIGHT(image)) * _WIDTH(image)
    'ELSE
    '    widthScaled = _WIDTH(0)
    '    heightScaled = (_WIDTH(0) / _WIDTH(image)) * _HEIGHT(image)
    'END IF
    widthScaled = _WIDTH(image) * imageScale
    heightScaled = _HEIGHT(image) * imageScale
    IF image < -1 THEN
        _PUTIMAGE (xOffset, yOffset)-(widthScaled + xOffset, heightScaled + yOffset), image
        LINE (xOffset, yOffset)-(widthScaled + xOffset, heightScaled + yOffset), _RGBA(0, 255, 0, 255), B
    ELSE
        LINE ((i - 1) * iW, _HEIGHT(0) / 2)-(i * iW, iW + _HEIGHT(0) / 2), _RGBA(255, 0, 0, 255), B
    END IF
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
    '$CHECKING:OFF
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
    '$CHECKING:ON
    _MEMFREE Buffer
END SUB

SUB parseImageToArray (Image AS LONG, array() AS pixel)
    IF Image > -2 THEN EXIT SUB
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
    '$CHECKING:OFF
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
    '$CHECKING:ON
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
    '$CHECKING:OFF
    DO
        _MEMPUT Buffer, O, (_MEMGET(Buffer, O, _UNSIGNED _BYTE) * B_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 1, (_MEMGET(Buffer, O + 1, _UNSIGNED _BYTE) * G_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 2, (_MEMGET(Buffer, O + 2, _UNSIGNED _BYTE) * R_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 3, (_MEMGET(Buffer, O + 3, _UNSIGNED _BYTE) * A_Frac) \ 65536 AS _UNSIGNED _BYTE
        O = O + 4
    LOOP UNTIL O = O_Last
    'turn checking back on when done!
    '$CHECKING:ON
    _MEMFREE Buffer
END SUB

SUB openFile (filename AS STRING)
    IF _FILEEXISTS(filename) THEN
        i = 0: DO: i = i + 1
            mousex = _MOUSEX
        LOOP WHILE _MOUSEINPUT AND i < 3

        IF NOT originalImageLoaded THEN
            what$ = "source"
            hHalf = _HEIGHT(0) / 2
            _PRINTSTRING (10, hHalf - _FONTHEIGHT - 10), "Trying to import " + what$ + " image... (This may take a while for big images)": _DISPLAY
            originalImage = _LOADIMAGE(filename, 32)
            originalImageLoaded = -1
        ELSE
            what$ = "reference"
            hHalf = _HEIGHT(0) / 2
            _PRINTSTRING (10, hHalf - _FONTHEIGHT - 10), "Trying to import " + what$ + " image... (This may take a while for big images)": _DISPLAY
            refImage = _LOADIMAGE(filename, 32)
            referenceImageLoaded = -1
        END IF

        IF originalImage < -1 AND refImage < -1 THEN
            _PRINTSTRING (10, hHalf - 10), "Generating tiles...": _DISPLAY
            IF UBOUND(originalImages) > 0 THEN
                DO: i = i + 1
                    IF originalImages(i) < -1 THEN _FREEIMAGE originalImages(i)
                    IF segmentedImages(i) < -1 THEN _FREEIMAGE segmentedImages(i)
                    IF refImages(i) < -1 THEN _FREEIMAGE refImages(i)
                LOOP UNTIL i = UBOUND(originalImages)
            END IF
            REDIM _PRESERVE AS LONG originalImages(0), segmentedImages(0), refImages(0), refImage

            ' divide image into smaller tiles, creates one tile if image is smaller
            i = 0
            yOffset = 1: DO
                xOffset = 1: DO
                    i = i + 1
                    REDIM _PRESERVE AS LONG originalImages(i), segmentedImages(i), refImages(i)
                    originalImages(i) = _NEWIMAGE(tileSize, tileSize, 32)
                    _PUTIMAGE (-xOffset, -yOffset)-(-xOffset + _WIDTH(originalImage), -yOffset + _HEIGHT(originalImage)), originalImage, originalImages(i)

                    segmentedImages(i) = _NEWIMAGE(tileSize, tileSize, 32)
                    '_PUTIMAGE (-xOffset, -yOffset)-(-xOffset + _WIDTH(refImage), -yOffset + _HEIGHT(refImage)), refImage, segmentedImages(i)

                    refImages(i) = _NEWIMAGE(tileSize, tileSize, 32)
                    IF refImage < -1 THEN
                        _PUTIMAGE (-xOffset, -yOffset)-(-xOffset + _WIDTH(refImage), -yOffset + _HEIGHT(refImage)), refImage, refImages(i)
                    END IF
                xOffset = xOffset + tileSize: LOOP UNTIL xOffset >= _WIDTH(originalImage)
            yOffset = yOffset + tileSize: LOOP UNTIL yOffset >= _HEIGHT(originalImage)

            IF originalImage < -1 THEN _FREEIMAGE originalImage
            IF refImage < -1 THEN _FREEIMAGE refImage
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

FUNCTION hr& (hue AS _FLOAT, saturation AS _FLOAT, lightness AS _FLOAT)
    SELECT CASE hue
        CASE IS < 60 AND hue >= 0: tr = 1
        CASE IS < 120 AND hue >= 60: tr = 1 - ((hue - 60) / 60)
        CASE IS < 180 AND hue >= 120: tr = 0
        CASE IS < 240 AND hue >= 180: tr = 0
        CASE IS < 300 AND hue >= 240: tr = (hue - 240) / 60
        CASE IS < 360 AND hue >= 300: tr = 1
    END SELECT
    hr& = tr * 255
END FUNCTION

FUNCTION hg& (hue AS _FLOAT, saturation AS _FLOAT, lightness AS _FLOAT)
    SELECT CASE hue
        CASE IS < 60 AND hue >= 0: tg = hue / 60
        CASE IS < 120 AND hue >= 60: tg = 1
        CASE IS < 180 AND hue >= 120: tg = 1
        CASE IS < 240 AND hue >= 180: tg = 1 - ((hue - 180) / 60)
        CASE IS < 300 AND hue >= 240: tg = 0
        CASE IS < 360 AND hue >= 300: tg = 0
    END SELECT
    hg& = tg * 255
END FUNCTION

FUNCTION hb& (hue AS _FLOAT, saturation AS _FLOAT, lightness AS _FLOAT)
    SELECT CASE hue
        CASE IS < 60 AND hue >= 0: tb = 0
        CASE IS < 120 AND hue >= 60: tb = 0
        CASE IS < 180 AND hue >= 120: tb = (hue - 120) / 60
        CASE IS < 240 AND hue >= 180: tb = 1
        CASE IS < 300 AND hue >= 240: tb = 1
        CASE IS < 360 AND hue >= 300: tb = 1 - ((hue - 300) / 60)
    END SELECT
    hb& = tb * 255
END FUNCTION

FUNCTION HSLtoRGB~& (conH, conS, conL, conA)
    IF conH >= 360 THEN
        conH = conH - (360 * INT(conH / 360))
    END IF

    objR = hr&(conH, conS, conL) * conS
    objG = hg&(conH, conS, conL) * conS
    objB = hb&(conH, conS, conL) * conS

    'maximizing to full 255
    IF objR >= objG AND objG >= objB THEN '123
        factor = 255 / objR
    ELSEIF objG >= objR AND objR >= objB THEN '213
        factor = 255 / objG
    ELSEIF objB >= objR AND objR >= objG THEN '312
        factor = 255 / objB
    ELSEIF objR >= objB AND objB >= objG THEN '132
        factor = 255 / objR
    ELSEIF objG >= objB AND objB >= objR THEN '231
        factor = 255 / objG
    ELSEIF objB >= objR AND objG >= objR THEN '321
        factor = 255 / objB
    END IF
    objR = objR * factor
    objG = objG * factor
    objB = objB * factor

    'adjusting to lightness
    objR = objR * conL
    objG = objG * conL
    objB = objB * conL

    'adjusting to saturation
    'IF objR = 0 OR objG = 0 OR objB = 0 THEN
    '    objavg = (objR + objG + objB) / 2
    'ELSE
    '    objavg = (objR + objG + objB) / 3
    'END IF
    'IF conS > 0.1 THEN
    '    objR = objR + ((objavg - objR) * (1 - conS))
    '    objG = objG + ((objavg - objG) * (1 - conS))
    '    objB = objB + ((objavg - objB) * (1 - conS))
    'ELSE
    '    objR = objavg
    '    objG = objavg
    '    objB = objavg
    'END IF

    HSLtoRGB~& = _RGBA(objR, objG, objB, conA)
END FUNCTION

FUNCTION getArgument$ (basestring AS STRING, argument AS STRING)
    getArgument$ = stringValue$(basestring, argument)
END FUNCTION

FUNCTION getArgumentv (basestring AS STRING, argument AS STRING)
    getArgumentv = VAL(stringValue$(basestring, argument))
END FUNCTION

FUNCTION stringValue$ (basestring AS STRING, argument AS STRING)
    IF LEN(basestring) > 0 THEN
        p = 1: DO
            IF MID$(basestring, p, LEN(argument)) = argument THEN
                endpos = INSTR(p + LEN(argument), basestring, ";")
                IF endpos = 0 THEN endpos = LEN(basestring) ELSE endpos = endpos - 1 'means that no comma has been found. taking the entire rest of the string as argument value.

                startpos = INSTR(p + LEN(argument), basestring, "=")
                IF startpos > endpos THEN
                    startpos = p + LEN(argument)
                ELSE
                    IF startpos = 0 THEN startpos = p + LEN(argument) ELSE startpos = startpos + 1 'means that no equal sign has been found. taking value right from the end of the argument name.
                END IF

                IF internal.setting.trimstrings = -1 THEN
                    stringValue$ = LTRIM$(RTRIM$(MID$(basestring, startpos, endpos - startpos + 1)))
                    EXIT FUNCTION
                ELSE
                    stringValue$ = MID$(basestring, startpos, endpos - startpos + 1)
                    EXIT FUNCTION
                END IF
            END IF
            finder = INSTR(p + 1, basestring, ";") + 1
            IF finder > 1 THEN p = finder ELSE stringValue$ = "": EXIT FUNCTION
        LOOP UNTIL p >= LEN(basestring)
    END IF
END FUNCTION

'--------------------------------------------------------------------------------------------------------------------------------------'

'$INCLUDE: 'dependencies/saveimage.bm'
'$INCLUDE: 'dependencies/opensave.bm'
