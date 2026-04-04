# frozen_string_literal: true

require_relative "../../test_helper"

class ShaderIOTest < Test::Unit::TestCase
  test "stores and retrieves values via method_missing" do
    io = RBGL::Engine::ShaderIO.new
    io.position = Larb::Vec3.new(1, 2, 3)
    assert_kind_of Larb::Vec3, io.position
  end

  test "stores and retrieves values via brackets" do
    io = RBGL::Engine::ShaderIO.new
    io[:color] = Larb::Color.new(1, 0, 0, 1)
    assert_kind_of Larb::Color, io[:color]
  end

  test "to_h returns data copy" do
    io = RBGL::Engine::ShaderIO.new
    io[:a] = 1
    io[:b] = 2
    h = io.to_h
    assert_equal({ a: 1, b: 2 }, h)
  end

  test "keys returns stored keys" do
    io = RBGL::Engine::ShaderIO.new
    io[:x] = 1
    io[:y] = 2
    assert_equal [:x, :y], io.keys
  end

  test "respond_to reports existing keys and writers" do
    io = RBGL::Engine::ShaderIO.new
    io[:anything] = 1

    assert_true io.respond_to?(:anything)
    assert_true io.respond_to?(:anything=)
    assert_false io.respond_to?(:missing)
  end

  test "raises on missing getter methods" do
    io = RBGL::Engine::ShaderIO.new

    assert_raise(NoMethodError) { io.missing }
  end
end

class UniformsTest < Test::Unit::TestCase
  test "initializes with empty data" do
    uniforms = RBGL::Engine::Uniforms.new
    assert_nil uniforms[:time]
  end

  test "initializes with hash" do
    uniforms = RBGL::Engine::Uniforms.new(time: 1.0, mouse: [0, 0])
    assert_equal 1.0, uniforms.time
    assert_equal [0, 0], uniforms.mouse
  end

  test "converts string keys to symbols" do
    uniforms = RBGL::Engine::Uniforms.new("time" => 1.0)
    assert_equal 1.0, uniforms[:time]
  end

  test "sets values via method_missing" do
    uniforms = RBGL::Engine::Uniforms.new
    uniforms.time = 2.0
    assert_equal 2.0, uniforms.time
  end

  test "merge creates new Uniforms" do
    u1 = RBGL::Engine::Uniforms.new(a: 1)
    u2 = u1.merge({ b: 2 })
    assert_equal 1, u2[:a]
    assert_equal 2, u2[:b]
    assert_nil u1[:b]
  end

  test "to_h returns data copy" do
    uniforms = RBGL::Engine::Uniforms.new(time: 1.0)
    h = uniforms.to_h
    assert_equal({ time: 1.0 }, h)
  end

  test "respond_to reports existing keys and writers" do
    uniforms = RBGL::Engine::Uniforms.new
    uniforms.time = 1.0

    assert_true uniforms.respond_to?(:time)
    assert_true uniforms.respond_to?(:time=)
    assert_false uniforms.respond_to?(:missing)
  end

  test "raises on missing getter methods" do
    uniforms = RBGL::Engine::Uniforms.new

    assert_raise(NoMethodError) { uniforms.time }
  end
end

class ShaderBuiltinsTest < Test::Unit::TestCase
  include RBGL::Engine::ShaderBuiltins

  test "vec2 creates Vec2" do
    v = vec2(1, 2)
    assert_kind_of Larb::Vec2, v
    assert_equal 1, v.x
    assert_equal 2, v.y
  end

  test "vec2 with single arg broadcasts" do
    v = vec2(5)
    assert_equal 5, v.x
    assert_equal 5, v.y
  end

  test "vec3 creates Vec3" do
    v = vec3(1, 2, 3)
    assert_kind_of Larb::Vec3, v
  end

  test "vec3 with single arg broadcasts" do
    v = vec3(5)
    assert_equal 5, v.x
    assert_equal 5, v.y
    assert_equal 5, v.z
  end

  test "vec3 with scalar and Vec2" do
    v = vec3(1, Larb::Vec2.new(2, 3))
    assert_equal 1, v.x
    assert_equal 2, v.y
    assert_equal 3, v.z
  end

  test "vec4 creates Vec4" do
    v = vec4(1, 2, 3, 4)
    assert_kind_of Larb::Vec4, v
  end

  test "vec4 with single arg broadcasts" do
    v = vec4(5)
    assert_equal 5, v.w
  end

  test "vec4 from Vec3 and scalar" do
    v = vec4(Larb::Vec3.new(1, 2, 3), 4)
    assert_equal 4, v.w
  end

  test "vec4 from two Vec2" do
    v = vec4(Larb::Vec2.new(1, 2), Larb::Vec2.new(3, 4))
    assert_equal 1, v.x
    assert_equal 4, v.w
  end

  test "dot returns dot product" do
    a = Larb::Vec3.new(1, 0, 0)
    b = Larb::Vec3.new(1, 0, 0)
    assert_equal 1.0, dot(a, b)
  end

  test "cross returns cross product" do
    a = Larb::Vec3.new(1, 0, 0)
    b = Larb::Vec3.new(0, 1, 0)
    c = cross(a, b)
    assert_equal 1.0, c.z
  end

  test "normalize returns unit vector" do
    v = Larb::Vec3.new(3, 0, 0)
    n = normalize(v)
    assert_in_delta 1.0, length(n), 0.001
  end

  test "length returns vector length" do
    v = Larb::Vec3.new(3, 4, 0)
    assert_equal 5.0, length(v)
  end

  test "mix interpolates numbers" do
    assert_equal 1.5, mix(1.0, 2.0, 0.5)
  end

  test "mix interpolates vectors" do
    a = Larb::Vec3.new(0, 0, 0)
    b = Larb::Vec3.new(2, 2, 2)
    c = mix(a, b, 0.5)
    assert_equal 1.0, c.x
  end

  test "clamp clamps number" do
    assert_equal 0.5, clamp(0.5, 0.0, 1.0)
    assert_equal 0.0, clamp(-1.0, 0.0, 1.0)
    assert_equal 1.0, clamp(2.0, 0.0, 1.0)
  end

  test "clamp clamps Vec3" do
    v = Larb::Vec3.new(-1, 0.5, 2)
    c = clamp(v, 0.0, 1.0)
    assert_equal 0.0, c.x
    assert_equal 0.5, c.y
    assert_equal 1.0, c.z
  end

  test "clamp clamps Vec2 and Vec4" do
    vec2 = clamp(Larb::Vec2.new(-1, 2), 0.0, 1.0)
    vec4 = clamp(Larb::Vec4.new(-1, 0.25, 2, 0.75), 0.0, 1.0)

    assert_equal 0.0, vec2.x
    assert_equal 1.0, vec2.y
    assert_equal 0.0, vec4.x
    assert_equal 0.25, vec4.y
    assert_equal 1.0, vec4.z
    assert_equal 0.75, vec4.w
  end

  test "clamp clamps colors" do
    c = clamp(Larb::Color.new(-1.0, 0.5, 2.0, 1.5), 0.0, 1.0)
    assert_equal 0.0, c.r
    assert_equal 0.5, c.g
    assert_equal 1.0, c.b
    assert_equal 1.0, c.a
  end

  test "saturate clamps to 0-1" do
    assert_equal 0.0, saturate(-1.0)
    assert_equal 1.0, saturate(2.0)
  end

  test "smoothstep returns smooth interpolation" do
    assert_equal 0.0, smoothstep(0.0, 1.0, 0.0)
    assert_equal 1.0, smoothstep(0.0, 1.0, 1.0)
    assert_in_delta 0.5, smoothstep(0.0, 1.0, 0.5), 0.01
  end

  test "step returns 0 or 1" do
    assert_equal 0.0, step(0.5, 0.3)
    assert_equal 1.0, step(0.5, 0.5)
    assert_equal 1.0, step(0.5, 0.7)
  end

  test "fract returns fractional part" do
    assert_in_delta 0.5, fract(1.5), 0.001
    assert_in_delta 0.3, fract(2.3), 0.001
  end

  test "mod returns modulo" do
    assert_in_delta 1.0, mod(5.0, 2.0), 0.001
  end

  test "abs returns absolute value" do
    assert_equal 5, abs(-5)
    v = abs(Larb::Vec3.new(-1, 2, -3))
    assert_equal 1.0, v.x
    assert_equal 3.0, v.z
  end

  test "abs returns absolute values for Vec2 and Vec4" do
    vec2 = abs(Larb::Vec2.new(-1, 2))
    vec4 = abs(Larb::Vec4.new(-1, 2, -3, 4))

    assert_equal 1.0, vec2.x
    assert_equal 2.0, vec2.y
    assert_equal 1.0, vec4.x
    assert_equal 3.0, vec4.z
  end

  test "sign returns -1, 0, or 1" do
    assert_equal(-1, sign(-5))
    assert_equal 0, sign(0)
    assert_equal 1, sign(5)
  end

  test "floor floors numbers" do
    assert_equal 1, floor(1.9)
  end

  test "floor floors Vec3" do
    v = floor(Larb::Vec3.new(1.9, 2.1, 3.5))
    assert_equal 1.0, v.x
  end

  test "floor floors Vec2 and Vec4" do
    vec2 = floor(Larb::Vec2.new(1.9, 2.1))
    vec4 = floor(Larb::Vec4.new(1.9, 2.1, 3.5, 4.9))

    assert_equal 1.0, vec2.x
    assert_equal 2.0, vec2.y
    assert_equal 3.0, vec4.z
    assert_equal 4.0, vec4.w
  end

  test "ceil ceils numbers" do
    assert_equal 2, ceil(1.1)
  end

  test "ceil ceils Vec3" do
    v = ceil(Larb::Vec3.new(1.1, 2.9, 3.5))
    assert_equal 2.0, v.x
    assert_equal 3.0, v.y
    assert_equal 4.0, v.z
  end

  test "ceil ceils Vec2 and Vec4" do
    vec2 = ceil(Larb::Vec2.new(1.1, 2.9))
    vec4 = ceil(Larb::Vec4.new(1.1, 2.9, 3.5, 4.1))

    assert_equal 2.0, vec2.x
    assert_equal 3.0, vec2.y
    assert_equal 4.0, vec4.z
    assert_equal 5.0, vec4.w
  end

  test "pow raises to power" do
    assert_equal 8, pow(2, 3)
  end

  test "pow raises Vec3 to power" do
    v = pow(Larb::Vec3.new(2, 3, 4), 2)
    assert_equal 4.0, v.x
    assert_equal 9.0, v.y
    assert_equal 16.0, v.z
  end

  test "pow raises Vec2 and Vec4 to powers" do
    vec2 = pow(Larb::Vec2.new(2, 3), 2)
    vec4 = pow(Larb::Vec4.new(2, 3, 4, 5), 2)

    assert_equal 4.0, vec2.x
    assert_equal 9.0, vec2.y
    assert_equal 16.0, vec4.z
    assert_equal 25.0, vec4.w
  end

  test "sqrt returns square root" do
    assert_equal 3.0, sqrt(9)
  end

  test "sqrt returns Vec3 square roots" do
    v = sqrt(Larb::Vec3.new(4, 9, 16))
    assert_equal 2.0, v.x
    assert_equal 3.0, v.y
    assert_equal 4.0, v.z
  end

  test "sqrt returns Vec2 and Vec4 square roots" do
    vec2 = sqrt(Larb::Vec2.new(4, 9))
    vec4 = sqrt(Larb::Vec4.new(4, 9, 16, 25))

    assert_equal 2.0, vec2.x
    assert_equal 3.0, vec2.y
    assert_equal 4.0, vec4.z
    assert_equal 5.0, vec4.w
  end

  test "reflect reflects vector" do
    v = Larb::Vec3.new(1, -1, 0)
    n = Larb::Vec3.new(0, 1, 0)
    r = reflect(v, n)
    assert_kind_of Larb::Vec3, r
  end

  test "refract refracts vector" do
    v = normalize(Larb::Vec3.new(1, -1, 0))
    n = Larb::Vec3.new(0, 1, 0)
    r = refract(v, n, 1.0)
    assert_kind_of Larb::Vec3, r
  end

  test "refract with total internal reflection" do
    v = normalize(Larb::Vec3.new(1, -0.1, 0))
    n = Larb::Vec3.new(0, 1, 0)
    r = refract(v, n, 10.0)
    assert_equal 0, r.x
    assert_equal 0, r.y
    assert_equal 0, r.z
  end

  test "mix interpolates colors" do
    a = Larb::Color.new(0, 0, 0, 1)
    b = Larb::Color.new(1, 1, 1, 1)
    c = mix(a, b, 0.5)
    assert_in_delta 0.5, c.r, 0.001
  end

  test "trig functions work" do
    assert_in_delta 0.0, sin(0), 0.001
    assert_in_delta 1.0, cos(0), 0.001
    assert_in_delta 0.0, tan(0), 0.001
    assert_in_delta 0.0, asin(0), 0.001
    assert_in_delta 0.0, acos(1), 0.001
    assert_in_delta 0.0, atan(0), 0.001
  end

  test "atan with two args uses atan2" do
    assert_in_delta Math::PI / 4, atan(1, 1), 0.001
  end

  test "min returns minimum" do
    assert_equal 1, min(1, 2, 3)
  end

  test "max returns maximum" do
    assert_equal 3, max(1, 2, 3)
  end

  test "texture samples through the texture object" do
    texture = Object.new
    texture.define_singleton_method(:sample) do |u, v, lod: 0|
      [u, v, lod]
    end

    assert_equal [0.25, 0.75, 0], self.texture(texture, Larb::Vec2.new(0.25, 0.75))
  end

  test "texture_lod forwards lod to the texture object" do
    texture = Object.new
    texture.define_singleton_method(:sample) do |u, v, lod: 0|
      [u, v, lod]
    end

    assert_equal [0.1, 0.9, 2], texture_lod(texture, Larb::Vec2.new(0.1, 0.9), 2)
  end

  test "rgb creates color" do
    c = rgb(1, 0, 0)
    assert_kind_of Larb::Color, c
  end

  test "rgba creates color with alpha" do
    c = rgba(1, 0, 0, 0.5)
    assert_equal 0.5, c.a
  end

  test "color_from_vec3 creates color" do
    c = color_from_vec3(Larb::Vec3.new(0.1, 0.2, 0.3))
    assert_equal 0.1, c.r
    assert_equal 0.2, c.g
    assert_equal 0.3, c.b
  end

  test "color_from_vec4 creates color" do
    c = color_from_vec4(Larb::Vec4.new(0.1, 0.2, 0.3, 0.4))
    assert_equal 0.1, c.r
    assert_equal 0.2, c.g
    assert_equal 0.3, c.b
    assert_equal 0.4, c.a
  end
end

class VertexShaderTest < Test::Unit::TestCase
  test "creates shader with block" do
    shader = RBGL::Engine::VertexShader.new do |input, uniforms, output|
      output.position = input[:position]
    end
    assert_not_nil shader
  end

  test "process runs shader block" do
    shader = RBGL::Engine::VertexShader.new do |input, _uniforms, output|
      output.position = input[:position]
      output.color = input[:color]
    end

    input = RBGL::Engine::ShaderIO.new
    input[:position] = Larb::Vec4.new(1, 2, 3, 1)
    input[:color] = Larb::Color.new(1, 0, 0, 1)

    result = shader.process(input, RBGL::Engine::Uniforms.new)
    assert_kind_of Larb::Vec4, result[:position]
  end

  test "raises error if position not set" do
    shader = RBGL::Engine::VertexShader.new do |_input, _uniforms, _output|
      # Not setting position
    end

    input = RBGL::Engine::ShaderIO.new
    assert_raise(RuntimeError) do
      shader.process(input, RBGL::Engine::Uniforms.new)
    end
  end

  test "create class method creates shader" do
    shader = RBGL::Engine::VertexShader.create do |_input, _uniforms, output|
      output.position = Larb::Vec4.new(0, 0, 0, 1)
    end
    assert_kind_of RBGL::Engine::VertexShader, shader
  end
end

class FragmentShaderTest < Test::Unit::TestCase
  test "creates shader with block" do
    shader = RBGL::Engine::FragmentShader.new do |_input, _uniforms, output|
      output.color = Larb::Color.new(1, 0, 0, 1)
    end
    assert_not_nil shader
  end

  test "process runs shader block" do
    shader = RBGL::Engine::FragmentShader.new do |_input, _uniforms, output|
      output.color = Larb::Color.new(1, 0, 0, 1)
    end

    result = shader.process(RBGL::Engine::ShaderIO.new, RBGL::Engine::Uniforms.new)
    assert_equal 1.0, result[:color].r
  end

  test "defaults to white color if not set" do
    shader = RBGL::Engine::FragmentShader.new do |_input, _uniforms, _output|
      # Not setting color
    end

    result = shader.process(RBGL::Engine::ShaderIO.new, RBGL::Engine::Uniforms.new)
    assert_kind_of Larb::Color, result[:color]
  end

  test "create class method creates shader" do
    shader = RBGL::Engine::FragmentShader.create do |_input, _uniforms, output|
      output.color = Larb::Color.new(0, 1, 0, 1)
    end
    assert_kind_of RBGL::Engine::FragmentShader, shader
  end
end
