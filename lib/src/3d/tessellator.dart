part of dtmark;

/**
 * The 3D equivelant of sprite batch, allows simple rendering of 3d
 * content by uploading vertices on the fly. This is not an effecient
 * way to render static 3d content, and you should consider storing
 * your static terrain/models in vertex buffers yourself.
 *
 * Later versions will allow you to add vertices to a
 * tessellator and automatically generate a buffer from
 * them. Technically you can already do this, but it requires more effort
 */
class Tessellator extends VertexBatch {

  //Vertex attribute indices
  static const int _ATTR_POS      = 0;
  static const int _ATTR_TEXCOORD = 1;
  static const int _ATTR_COLOR    = 2;
  static const int _ATTR_NORMAL   = 3;

  /**
   * Current normal vector used when adding vertices
   */
  Vector3 normal = new Vector3(0.0, 0.0, 0.0);

  Tessellator(WebGL.RenderingContext gl) : super(gl,
      [new VertexAttrib(_ATTR_POS,      3),
       new VertexAttrib(_ATTR_TEXCOORD, 2),
       new VertexAttrib(_ATTR_COLOR,    4),
       new VertexAttrib(_ATTR_NORMAL,   3)], quadInput: true) {
    //Quad input is passed to super() as true, but then immediately set to
    //false. This is because the indices are not generated unless quad input
    //is initially passed in as true, but I want the default mode to be
    //triangles
    _shader = getTessShader(gl);
    _quadInput = false;
    useTexture = false;
    useColor   = false;
    useNormals = false;
  }

  /**
   * Adds a vertex to the tessellator with the given texture coords
   */
  void vertexUV(double x, double y, double z, double u, double v) {
    _flushIfNeeded();
    verts[_vOff + 0] = x;
    verts[_vOff + 1] = y;
    verts[_vOff + 2] = z;
    _vOff += 3;
    if (useTexture) {
      verts[_vOff + 0] = u;
      verts[_vOff + 1] = v;
      _vOff += 2;
    }
    if (useColor) {
      verts[_vOff + 0] = color.r;
      verts[_vOff + 1] = color.g;
      verts[_vOff + 2] = color.b;
      verts[_vOff + 3] = color.a;
      _vOff += 4;
    }
    if (useNormals) {
      verts[_vOff + 0] = normal.x;
      verts[_vOff + 1] = normal.y;
      verts[_vOff + 2] = normal.z;
      _vOff += 3;
    }
  }

  /**
   * Adds a vertex to the tessellator with texture coords of (0.0, 0.0)
   */
  void vertex(double x, double y, double z) {
    vertexUV(x, y, z, 0.0, 0.0);
  }

  @override
  void begin() {
    super.begin();
    if (!useColor)
      gl.vertexAttrib4f(_ATTR_COLOR, 1.0, 1.0, 1.0, 1.0);
  }

  /**
   * Begins saving vertices, but does not set up GL state for rendering
   */
  void beginSaving() {
    _vOff = 0;
  }

  /**
   * Save the current vertices as a new Geometry. If [bakeModelView] is true,
   * each position will be transformed with the modelView matrix before
   * being saved.
   */
  Geometry save([bool bakeModelView = false]) {
    Float32List geomVerts = null;
    if (useQuads) {
      //TODO: triangulate faces
    } else {
      geomVerts = new Float32List(_vOff);
      for (int i = 0; i < _vOff; i++) {
        geomVerts[i] = verts[i];
      }
    }
    _vOff = 0;
    Geometry geom = new Geometry(gl, geomVerts);
    geom.hasTexture = useTexture;
    geom.hasColor   = useColor;
    geom.hasNormals = useNormals;
    geom.transform  = modelView.clone();
    if (bakeModelView)
      geom.bakeTransform();
    return geom;
  }

  /**
   * Renders some geometry. Don't call between [begin] and [end]
   */
  void renderGeometry(Geometry geom) {
    _shader.use();
    _transform.setFrom(_projection);
    _transform.multiply(_modelView);
    if (geom.transform != null)
      _transform.multiply(geom.transform);

    _shader.setUniformMatrix4fv("u_transform", false, _transform);
    _shader.setUniform1i("u_texture", 0);

    if (geom.hasTexture)
      _lastTex.bind();
    else
      _whiteTex.bind();

    if (!geom.hasColor)
      gl.vertexAttrib4f(_ATTR_COLOR, 1.0, 1.0, 1.0, 1.0);

    gl.enableVertexAttribArray(_ATTR_POS);
    if (geom.hasTexture)
      gl.enableVertexAttribArray(_ATTR_TEXCOORD);
    if (geom.hasColor)
      gl.enableVertexAttribArray(_ATTR_COLOR);
    if (geom.hasNormals)
      gl.enableVertexAttribArray(_ATTR_NORMAL);

    geom.render();

    gl.disableVertexAttribArray(_ATTR_POS);
    if (geom.hasTexture)
      gl.disableVertexAttribArray(_ATTR_TEXCOORD);
    if (geom.hasColor)
      gl.disableVertexAttribArray(_ATTR_COLOR);
    if (geom.hasNormals)
      gl.disableVertexAttribArray(_ATTR_NORMAL);
  }

  set texture(Texture tex) {
    _switchTexture(tex == null ? _whiteTex : tex);
  }

  set useTexture(bool useTex) {
    _attribs[_ATTR_TEXCOORD].active = useTex;
  }

  set useColor(bool useCol) {
    _attribs[_ATTR_COLOR].active = useCol;
  }

  set useNormals(bool useNorm) {
    _attribs[_ATTR_NORMAL].active = useNorm;
  }

  set useQuads(bool useQuads) {
    _quadInput = useQuads;
  }

  /**
   * Texture that will be used when rendering vertices. Setting this
   * to null will reset it to a 1x1 pixel white texture
   */
  Texture get texture => _lastTex;

  /**
   * Whether or not texture coordinates should be used
   */
  bool get useTexture => _attribs[_ATTR_TEXCOORD].active;

  /**
   * Whether or not color should be used. If false, color will default to white
   */
  bool get useColor => _attribs[_ATTR_COLOR].active;

  /**
   * Whether or not normals should be used
   */
  bool get useNormals => _attribs[_ATTR_NORMAL].active;

  /**
   * Whether or not the input vertices will be interpreted as quads. If false,
   * they will be considered triangles
   */
  bool get useQuads => _quadInput;

  /**
   * The current shader program used when rendering the batch. Setting
   * this will not affect anything until the next time [begin] is called.
   * Setting this to null will reset the shader to the default Tessellator
   * shader.
   */
  @override
  set shader(Shader shader) {
    _shader = shader == null ? _tessShader : shader;
  }

  static Shader _tessShader;

  /**
   * Returns the default SpriteBatch shader. Creates it if it doesn't exist yet.
   */
  static Shader getTessShader(WebGL.RenderingContext gl) {
    if (_tessShader == null) {
      _tessShader = new Shader(VERT_SHADER, FRAG_SHADER, gl,
        name: "SpriteBatch Shader", attribLocs: const [
          const AttribLocation(_ATTR_POS,      "a_position"),
          const AttribLocation(_ATTR_TEXCOORD, "a_texCoord"),
          const AttribLocation(_ATTR_COLOR,    "a_color")
        ]);
    }
    return _tessShader;
  }

  /**
   * GLSL code of the default vertex shader
   */
  static const String VERT_SHADER =
"""
uniform mat4 u_transform;

attribute vec3 a_position;
attribute vec2 a_texCoord;
attribute vec4 a_color;

varying vec2 v_texCoord;
varying vec4 v_color;

void main() {
  v_texCoord = a_texCoord;
  v_color = a_color;
  gl_Position = u_transform * vec4(a_position, 1.0);
}
""";

  /**
   * GLSL code of the default fragment shader
   */
  static const String FRAG_SHADER =
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
""";
}
