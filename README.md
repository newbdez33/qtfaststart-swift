# QTFastStart

The code is written by the author from this link:
http://throughkim.kr/2020/02/25/qt-faststart-in-swift/

This library is swift version of [qtfaststart.c](https://github.com/FFmpeg/FFmpeg/blob/master/tools/qt-faststart.c)

## Usage

```swift
do {
    let m4a = try Data(contentsOf: URL(fileURLWithPath: "/Users/jacky/Desktop/134646452-44100-2-fdf33f73afe05.m4a"))
    let optmized = QTFastStart().process(m4a)
    try optmized.write(to: URL(fileURLWithPath: "/Users/jacky/Desktop/optimized.m4a"))
} catch {
    print(error)
}
```

