part of dtmark;

//TODO Add Z index (make it a vert attrib) so that things don't have to be painter's algorithim. good idea? maybe...
class SpriteBatch {
  
  //Max 1024 quads before flush
  static const int BATCH_MAX_VERTS = 1024 * 6;
//  static Matrix4 _ident = new Matrix4.identity();
  
  //X,Y,U,V,R,G,B,A
  Float32List verts = new Float32List(8 * BATCH_MAX_VERTS);
  WebGL.RenderingContext gl;
  WebGL.Buffer buffer;
  Shader _shader;
  
  Texture whiteTex;
  Texture _lastTex = null;
  Vector4 color = new Vector4(1.0, 1.0, 1.0, 1.0);
  int vOff = 0;
  
  Matrix4 _projection;
  Matrix4 _modelView;
  bool _rendering = false;
  
  bool _texChanged = false;
  bool transformChanged = false;
  
  SpriteBatch(this.gl, {int width: 1, int height: 1}) {
    _shader = getBatchShader(gl);
    buffer = gl.createBuffer();
    
    whiteTex = new Texture(null, gl);
    gl.texImage2DTyped(WebGL.TEXTURE_2D, 0, WebGL.RGBA, 1, 1, 0, WebGL.RGBA, WebGL.UNSIGNED_BYTE, new Uint8List.fromList([255, 255, 255, 255]));
    
    _projection = makeOrthographicMatrix(0, width, 0, height, -1, 1);
    _modelView = new Matrix4.identity();
    _lastTex = whiteTex;
    //Trigger a calc of the transform matrix
    transformChanged = true;
  }
  
  void _addVert(double x, double y, double u, double v) {
    if (vOff >= verts.length) {
      _flush();
    }
    verts[vOff + 0] = x;
    verts[vOff + 1] = y;
    verts[vOff + 2] = u;
    verts[vOff + 3] = v;
    verts[vOff + 4] = color.r;
    verts[vOff + 5] = color.g;
    verts[vOff + 6] = color.b;
    verts[vOff + 7] = color.a;
    vOff += 8;
  }
  
  //Vertex 0 is top left, Vertex 1 is bottom right
  void _addQuad(double x0, double y0, double u0, double v0, double x1, double y1, double u1, double v1) {
    
    //Top left, bottom left, bottom right, bottom right, top right, top left
    _addVert(x0, y0, u0, v0);
    _addVert(x0, y1, u0, v1);
    _addVert(x1, y1, u1, v1);
    
    _addVert(x1, y1, u1, v1);
    _addVert(x1, y0, u1, v0);
    _addVert(x0, y0, u0, v0);
  }
  
  void _switchTexture(Texture tex) {
    if (_lastTex == null || _lastTex != tex) {
      _flush();
      _texChanged = true;
      _lastTex = tex;
    }
  }
  
  void fillRect(double x, double y, double width, double height) {
    drawTexture(whiteTex, x, y, width, height);
  }
  
  void drawTexture(Texture tex, double x, double y, [double width, double height]) {
    _switchTexture(tex);
    if (width == null) {
      width = tex.width.toDouble();
    }
    if (height == null) {
      height = tex.height.toDouble();
    }
    _addQuad(x, y + height, 0.0, 0.0, x + width, y, tex.maxU, tex.maxV);
  }
  
  void drawTexScaled(Texture tex, double x, double y, double scale) {
    drawTexture(tex, x, y, tex.width * scale, tex.height * scale);
  }
  
  void drawTexRegion(Texture tex, double x, double y, double width, double height, int texX, int texY, int texWidth, int texHeight) {
    double w = 1 / tex.width;
    double h = 1 / tex.height;
    double u0 = texX * w;
    double v0 = texY * h;
    double u1 = u0 + texWidth * w;
    double v1 = v0 + texHeight * h;
    drawTexRegionUV(tex, x, y, width, height, u0, v0, u1, v1);
  }
  
  void drawTexRegionUV(Texture tex, double x, double y, double width, double height, double u0, double v0, double u1, double v1) {
    _switchTexture(tex);
    _addQuad(x, y + height, u0, v0, x + width, y, u1, v1);
  }
  
  set projection(Matrix4 proj) {
    if (_rendering) {
      _flush();
    }
    if (proj == null) {
      _projection = new Matrix4.identity();
    } else {
      _projection = proj;
    }
    transformChanged = true;
  }
  
  set modelView(Matrix4 mview) {
    if (_rendering) {
      _flush();
    }
    if (mview == null) {
      _modelView = new Matrix4.identity();
    } else {
      _modelView = mview;
    }
    transformChanged = true;
  }
  
  set shader(Shader shader) {
    if (shader == null) {
      _shader = _batchShader;
    } else {
      _shader = shader;
    }
  }
  
  Matrix4 get projection => _projection;
  Matrix4 get modelView => _modelView;
  
  void begin() {
    _rendering = true;
    _texChanged = true;
    transformChanged = true;
    color.setValues(1.0, 1.0, 1.0, 1.0);
    _shader.use();
    _shader.setUniform1i("u_texture", 0);
    gl.enableVertexAttribArray(0);
    gl.enableVertexAttribArray(1);
    gl.enableVertexAttribArray(2);
    
    gl.bindBuffer(WebGL.ARRAY_BUFFER, buffer);
    gl.vertexAttribPointer(0, 2, WebGL.FLOAT, false, 32, 0);
    gl.vertexAttribPointer(1, 2, WebGL.FLOAT, false, 32, 8);
    gl.vertexAttribPointer(2, 4, WebGL.FLOAT, false, 32, 16);
  }
  
  void end() {
    _flush();
    gl.disableVertexAttribArray(0);
    gl.disableVertexAttribArray(1);
    gl.disableVertexAttribArray(2);
    _rendering = false;
  }
  
  void flush() {
      _flush();
  }
  
  void _flush() {
    if (vOff > 0) {
      if (transformChanged) {
        _shader.setUniformMatrix4fv("u_transform", false, _projection * _modelView);
        transformChanged = false;
      }
      
      if (_texChanged) {
        if (_lastTex != null) {
          _lastTex.bind();
        }
        _texChanged = false;
      }
      //Buffer streaming!
      gl.bufferData(WebGL.ARRAY_BUFFER, verts.lengthInBytes, WebGL.STREAM_DRAW);
      gl.bufferSubDataTyped(WebGL.ARRAY_BUFFER, 0, new Float32List.view(verts.buffer, 0, vOff));
      
      gl.drawArrays(WebGL.TRIANGLES, 0, (vOff >> 3));
    }
    vOff = 0;
  }
  
  static Shader _batchShader;
  static Shader getBatchShader(WebGL.RenderingContext gl) {
    if (_batchShader == null) {
      _batchShader = new Shader(
"""
uniform mat4 u_transform;

attribute vec2 a_position;
attribute vec2 a_texCoord;
attribute vec4 a_color;

varying vec2 v_texCoord;
varying vec4 v_color;

void main() {
  v_texCoord = a_texCoord;
  v_color = a_color;
  gl_Position = u_transform * vec4(a_position, 0.0, 1.0);
}
"""
, 
"""
precision mediump float;
uniform sampler2D u_texture;

varying vec2 v_texCoord;
varying vec4 v_color;

void main() {
  vec4 color = texture2D(u_texture, v_texCoord) * v_color;
  if (color.a == 0.0) {
    discard;
  }
  gl_FragColor = color; 
}
""", gl);
      _batchShader.bindAttribLocation(0, "a_position");
      _batchShader.bindAttribLocation(1, "a_texCoord");
      _batchShader.bindAttribLocation(2, "a_color");
    }
    return _batchShader;
  }
}