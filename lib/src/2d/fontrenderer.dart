part of dtmark;

/**
 * A FontRenderer which can render text using a SpriteBatch. Only
 * supports character codes from 0 to 255. All text characters are
 * stored in one texture. The FontRenderer can generate a font on the fly
 * with canvas, load a varying width font from JSON + an image, or load a
 * monospace font from just an image. It also has a low-res font embedded
 * in it (no support for accent marks).
 */
class FontRenderer {

  /**
   * When drawing a string, width and height is multiplied by this
   */
  double scale = 1.0;

  /**
   * The height of the font
   */
  int size = 0;

  /**
   * Array of all character widths in pixels
   */
  final Float32List charWidths = new Float32List(256);

  /**
   * Array of all character heights in pixels
   */
  final Float32List charHeights = new Float32List(256);

  /**
   * Array of top left U texture coordinates
   */
  final Float32List charU0 = new Float32List(256);

  /**
   * Array of bottom right U texture coordinates
   */
  final Float32List charU1 = new Float32List(256);

  /**
   * Array of top left V texture coordinates
   */
  final Float32List charV0 = new Float32List(256);

  /**
   * Array of bottom right V texture coordinates
   */
  final Float32List charV1 = new Float32List(256);

  /**
   * Amount of empty space to add between each text character
   */
  double xSpacing = 0.0;

  /**
   * Texture containing font characters
   */
  Texture _tex;

  Future<FontRenderer> _onLoad;

  /**
   * Loads a font using data in a JSON file at [url].
   *
   * Below is a sample JSON file for a rather useless font that includes
   * only the letter 'A', and uses the entire texture for it.
   *
   *     {
   *       "textureUrl": "res/font/uselessfont.png",
   *       "size": 7,
   *       "xSpacing": 1
   *       "chars": [
   *         {
   *           "charCode": 65,
   *           "width": 5,
   *           "height": 7,
   *           "u0": 0.0,
   *           "v0": 0.0,
   *           "u1": 1.0,
   *           "v1": 1.0
   *         }
   *       ]
   *     }
   */
  FontRenderer(String url, WebGL.RenderingContext gl) {
    _onLoad = HttpRequest.getString(url).then((text) {
      var fontInfo = JSON.decode(text);
      _tex = new Texture.load(fontInfo["textureUrl"], gl);
      List chars = fontInfo["chars"];
      size = fontInfo["size"];
      xSpacing = fontInfo["xSpacing"];
      for (final c in chars) {
        int code = c["charCode"];
        charWidths[code] = c["width"];
        charHeights[code] = c["height"];
        charU0[code] = c["u0"];
        charV0[code] = c["v0"];
        charU1[code] = c["u1"];
        charV1[code] = c["v1"];
      }
      return _tex.onLoad.then((_) => this);
    });
  }

  /**
   * Creates a monospace font renderer from an existing texture [tex].
   * [charWidth] and [charHeight] define the dimensions of the actual
   * text characters, while [cellWidth] and [cellHeight] define the
   * dimensions of each cell. See FontRenderer.lowResMono src for example.
   * Size is set to charHeight unless [size] is defined. [xSpacing]
   * defaults to 1
   */
  FontRenderer.mono(Texture tex, WebGL.RenderingContext gl, int charWidth,
      int charHeight, int cellWidth, int cellHeight, {int xSpacing: 1, int size: -1}) {

    this.size = size == -1 ? charHeight : size;
    this.xSpacing = xSpacing.toDouble();
    for (var i = 0; i < 256; i++) {
      charWidths[i] = charWidth.toDouble();
      charHeights[i] = charHeight.toDouble();
    }
    _tex = tex;
    _onLoad = tex.onLoad.then((_) {
      double cwidth = charWidth / tex.width;
      double cheight = charHeight / tex.height;

      //U/V width/heights of each character cell
      double texWidth = cellWidth / tex.width;
      double texHeight = cellHeight / tex.height;

      for (var i = 0; i < 256; i++) {
        charU0[i] = (i & 15) * texWidth;
        charV0[i] = (i >> 4) * texHeight;
        charU1[i] = charU0[i] + cwidth;
        charV1[i] = charV0[i] + cheight;
      }
      return this;
    });
  }

  /**
   * Creates a 6 wide by 8 tall monospace font from an embedded image
   */
  factory FontRenderer.lowResMono(WebGL.RenderingContext gl) {
    //Image data, see res/font_bmp.png. Dimensions are 96x128
    const String base64img =
      '''
data:image/png;base64,
iVBORw0KGgoAAAANSUhEUgAAAGAAAACACAYAAAD03Gy6AAAE5ElEQVR42u2c25LbIBBEkYv//2Xl
JXKp8NwBrzY5vQ+OWVagaRimB8hxnufZjna0G452tLOdbQTl68tfrbUm/hZ8Ba/3vyDhhwmAhAcQ
MKwF4JsEYPwfJADjg/8VB/H4E3QAeEgUBCAAAgAEQAAA6ICr/Gzv/YJ3+VX299Mtl55znueowj+e
E+3PBa0/2ef8czrgat3Ktt7raD322hhTKtJzst8326RvM/IwG0T6LePNGn8k4fr9nZTZdhf0t0bA
/WWkF9VeePwbyQgWadLfV19e+hwHk9WW5lOSg2X/DLBGu2RozUDLVj3BTd0/tT5JA27BTH2lOxyd
FaPRrx/pRa/fWa7Da1vz3REXuMoG4/sG+vEKj+wVoy4ygi5jZhdjbcHNGk+qv2IWsufyZB0wLJIh
HTDWv+L6+8OP41DjdK/+ze+69bX+W+9Vid8lfSPV1/SH0J/+Mb1G3+xNx+u7F1ZmogYtprd0g7aI
W+8VWWwrbshr//a9m0aSqPY64UU2WntWFLLDJ8/qDG9ASeG4gO4aqao+PYNaeqCiG6QFX3uXjMaY
iaK0SO5DiFVGVEZ9jiLHa6uiG6TvY7nnarR4v+pSA/3t5Tg30ljWmN90IRk9IZFQdZNDWTdTBdJC
JyXWrkXYch3ey0ZTF9HnWCM9s/hXhKFV76fyT6CiAyLxfrW+Ftdn4/3xfsPZTlcfDDP43a70HO3+
RLS+059eiqNX1J+NRqKLueWLtd9lXU0kclT6v+9+wG4/t+v5s4IraUtbiFkZxhWG8BZPK1Qcxdu3
jV+deSYBVrRgGava6cqmiyfWZsio7D94UZODffcDnnrbxutXZT96wk32cr4nE79HR6s38isb9dLC
7205Wkq+Oliz+gZ8SwesiuvH+l5cn42jV5ZndIaX97d0RuDcUV8W13u5j6dIcC9kjOa4rCgscaDg
958NnTnnkxFzlWcG/raX4voVSbSVsbqWrbRG4grBFZlhoRlw3H4iYZuWSrg/pxrKVUa0lhJYYfwd
4WnKBWkvsalDUzMi0qdZ4bj4nXuoMY+EipawXFbFpcyIscgewqzqrh5lBLt1gHeOfhy0s/+/0D0/
btUfzwVV+7PiPsEwK9bfD3iKPx/9tHRq+f4zm4/JnnvdgG42EkkLZ3I+kdRyVMhpqfOoP/d8vbfO
aOvjuCY69ulh5q2TzdHdJet4ytjxzEKr9c07G5Q9UW1FiFn7iCfjoqnbVWFc9AhIxJg7hd5suqMU
hnpTfkdeJlO/2h/PwNkwd5KsHh6t1VRENDSopkAi9VftB6wUcWiAJ+mABfFs6bz87nar5X+/fNxX
iN5zTusAIGsQz6Volk2sTy9T3NzLpE+tvhTpRC9If6O8IuiyBEYup7cW3BGzLr9FdsR27oZlk3SB
Wyvl9qXgw3leD0c12kt8e0MmGjp66ZXoxs5MWBs+mLUq9RoZTd5RvspOllbfuqDxkDBw/U15bZaM
sbe03xAZ0Zbst1ynd7/B6quXCwLoAMrRAb8TEAABEAAgAAIAQAcQp6MDWAMABEAAgAAIAAAdQDk6
gDUAQAAEAAiAAADQAZSjA1gDAARAAIAACAAAHUA5OoA1AEAABAAIgAAA0AGUowNYAwAEQACAAAgA
AB1AOTqANQBAAAQACIAAANABlKMDWAMABEAAgAAIAOAZ+AOg2b+6t+iJHQAAAABJRU5ErkJggg==
      ''';
    var src = base64img.replaceAll("\n", "");
    var tex = new Texture.load(src, gl);
    return new FontRenderer.mono(tex, gl, 5, 7, 6, 8);
  }

  /**
   * Generates a font at runtime with the Canvas 2D context. [font] defines
   * the name of the font (don't include size in it). [size] is the size
   * of the font in pixels. For example, using a font of Arial and a size
   * of 32 will create the font from "32px Arial". Only generates
   * characters 0 - 127
   */
  FontRenderer.generate(String font, this.size, WebGL.RenderingContext gl) {
    _onLoad = new Future.value(this);
    var canvas = new CanvasElement();
    CanvasRenderingContext2D ctx = canvas.getContext("2d");
    ctx.font = "$size\px $font";
    List<int> points = new List.generate(128, (i) => i, growable: false);
    String chars = UTF8.decode(points, allowMalformed: true);
    double maxWidth = 0.0;
    double charHeight = (size.toDouble() + (size / 8)).ceilToDouble();
    for (int i = 0; i < 128; i++) {
      var char = chars.substring(i, i + 1);
      var metrics = ctx.measureText(char);
      charWidths[i] = metrics.width;
      charHeights[i] = charHeight;
      maxWidth = Math.max(maxWidth, metrics.width);
    }

    maxWidth += 2.0;
    charHeight += 2.0;

    int width = nextPowerOf2((maxWidth * 16).toInt());
    int height = nextPowerOf2((charHeight * 8).toInt());

    double oneOverW = 1 / width;
    double oneOverH = 1 / height;

    double cellOffX = width / 16;
    double cellOffY = height / 8;

    canvas.width = width;
    canvas.height = height;

    ctx.font = "$size\px $font";
    ctx.fillStyle = "#FFFFFF";
    ctx.textBaseline = "top";
    ctx.translate(1, 1);
    for (int i = 0; i < 128; i++) {
      var char = chars.substring(i, i + 1);
      charU0[i] = (i & 15) / 16.0 + oneOverW;
      charV0[i] = (i >> 4) / 8.0 + oneOverH;
      charU1[i] = charU0[i] + charWidths[i] * oneOverW;
      charV1[i] = charV0[i] + charHeights[i] * oneOverH;

      ctx.fillText(char, (i & 15) * cellOffX, (i >> 4) * cellOffY);
    }

    _tex = new Texture(canvas, gl, mipmap: true);
    _tex.minFilter = WebGL.LINEAR_MIPMAP_LINEAR;
    _tex.magFilter = WebGL.LINEAR;
  }

  /**
   * Gets the width of the string in pixels multiplied by the current scale
   */
  double getWidth(String str) {
    double w = str.codeUnits.fold(0.0, (a, code) => a + charWidths[code]);
    return (w + xSpacing * str.length) * scale;
  }

  /**
   * The size of the font multiplied by the scale
   */
  double get height => size * scale;

  Future<FontRenderer> get onLoad => _onLoad;

  /**
   * Draws [str] at ([x], [y]) using [batch]. This should be used after [batch.begin]
   * has been called. Drawing multiples strings in a row will therefor
   * only result in one draw call if used with one batch.
   */
  void drawString(SpriteBatch batch, String str, double x, double y) {
    for (final code in str.codeUnits) {
      if (code >= 256)
        continue;
      _drawChar(batch, code, x, y);
      x += (charWidths[code] + xSpacing) * scale;
    }
  }

  /**
   * Draws [str] using [batch], centering it at ([x], [y]). See
   * [drawString] for more details.
   */
  void drawStringCentered(SpriteBatch batch, String str, double x, double y) {
    int w = (getWidth(str) * 0.5).floor();
    drawString(batch, str, x - w, y);
  }

  void _drawChar(SpriteBatch batch, int code, double x, double y) {
    batch.drawTexRegionUV(_tex, x, y,
      charWidths[code] * scale, charHeights[code] * scale,
      charU0[code], charV0[code],
      charU1[code], charV1[code]);
  }

}
