# frozen_string_literal: true

require_relative "../../test_helper"

class FileBackendGoldenTest < Test::Unit::TestCase
  FIXTURE_DIR = File.join(__dir__, "..", "..", "fixtures", "golden")
  WIDTH = 16
  HEIGHT = 16

  setup do
    @tmpdir = Dir.mktmpdir
    @frame_path = File.join(@tmpdir, "frame.ppm")
  end

  teardown do
    FileUtils.rm_rf(@tmpdir)
  end

  test "clear color renders the expected golden image" do
    actual_path = render_case do |context|
      context.clear(color: Larb::Color.from_hex("#223344"))
    end

    assert_golden_image(actual_path, "clear_color.ppm")
  end

  test "simple triangle renders the expected golden image" do
    actual_path = render_case do |context|
      pipeline = triangle_pipeline
      vertices = triangle_vertices

      context.clear(color: Larb::Color.black)
      context.bind_pipeline(pipeline)
      context.bind_vertex_buffer(vertices)
      context.draw_arrays(:triangles, 0, 3)
    end

    assert_golden_image(actual_path, "triangle.ppm")
  end

  test "depth test renders the expected golden image" do
    actual_path = render_case do |context|
      pipeline = triangle_pipeline
      pipeline.cull_mode = :none
      context.clear(color: Larb::Color.from_hex("#000000"))

      context.bind_pipeline(pipeline)
      context.bind_vertex_buffer(depth_vertices_far)
      context.draw_arrays(:triangles, 0, 3)

      context.bind_vertex_buffer(depth_vertices_near)
      context.draw_arrays(:triangles, 0, 3)
    end

    assert_golden_image(actual_path, "depth_test.ppm")
  end

  private

  def render_case
    context = RBGL::Engine::Context.new(width: WIDTH, height: HEIGHT)
    backend = RBGL::GUI::FileBackend.new(
      WIDTH,
      HEIGHT,
      "rbgl golden",
      format: :ppm,
      ppm_mode: :binary,
      output_dir: @tmpdir
    )

    yield context
    backend.present(context.framebuffer)
    backend.close

    backend_path = File.join(@tmpdir, "frame_00000.ppm")
    backend_path
  ensure
    backend.close if defined?(backend) && backend
  end

  def triangle_pipeline
    RBGL::Engine::Pipeline.create do
      vertex do |input, _uniforms, output|
        output.position = input.position.to_vec4
        output.color = input.color
      end

      fragment do |input, _uniforms, output|
        output.color = input.color
      end
    end
      .tap { |pipeline| pipeline.cull_mode = :none }
  end

  def triangle_vertices
    RBGL::Engine::VertexBuffer.from_array(
      RBGL::Engine::VertexLayout.position_color,
      [
        { position: Larb::Vec3[-0.5, 0.5, 0.0], color: Larb::Color.red },
        { position: Larb::Vec3[-0.8, -0.5, 0.0], color: Larb::Color.green },
        { position: Larb::Vec3[0.5, -0.3, 0.0], color: Larb::Color.blue }
      ]
    )
  end

  def depth_vertices_far
    RBGL::Engine::VertexBuffer.from_array(
      RBGL::Engine::VertexLayout.position_color,
      [
        { position: Larb::Vec3[0.0, 0.8, 0.9], color: Larb::Color.red },
        { position: Larb::Vec3[-0.8, -0.2, 0.9], color: Larb::Color.red },
        { position: Larb::Vec3[0.8, -0.2, 0.9], color: Larb::Color.red }
      ]
    )
  end

  def depth_vertices_near
    RBGL::Engine::VertexBuffer.from_array(
      RBGL::Engine::VertexLayout.position_color,
      [
        { position: Larb::Vec3[0.0, 0.8, 0.1], color: Larb::Color.green },
        { position: Larb::Vec3[-0.8, -0.2, 0.1], color: Larb::Color.green },
        { position: Larb::Vec3[0.8, -0.2, 0.1], color: Larb::Color.green }
      ]
    )
  end

  def assert_golden_image(actual_path, fixture_name, max_delta: 0, allowed_pixels: 0)
    expected_path = File.join(FIXTURE_DIR, fixture_name)
    actual = File.binread(actual_path)

    if !File.exist?(expected_path) && ENV["RBGL_UPDATE_GOLDEN"] == "1"
      File.binwrite(expected_path, actual)
      return
    end

    expected = File.binread(expected_path)

    if ENV["RBGL_UPDATE_GOLDEN"] == "1" && (expected != actual)
      File.binwrite(expected_path, actual)
      return
    end

    if max_delta.zero? && allowed_pixels.zero?
      assert_equal expected, actual
      return
    end

    expected_data_offset = ppm_binary_data_offset(expected)
    actual_data_offset = ppm_binary_data_offset(actual)
    expected_header = expected.byteslice(0, expected_data_offset)
    actual_header = actual.byteslice(0, actual_data_offset)
    assert_equal expected_header, actual_header

    expected_pixels = expected.byteslice(expected_data_offset..)
    actual_pixels = actual.byteslice(actual_data_offset..)
    assert_equal expected_pixels.bytes.length, actual_pixels.bytes.length

    mismatched_pixels = 0
    bytes_per_pixel = 3

    expected_pixels.bytes.each_slice(bytes_per_pixel).with_index do |expected_pixel, pixel_index|
      actual_pixel = actual_pixels.bytes.slice(pixel_index * bytes_per_pixel, bytes_per_pixel)
      next if expected_pixel == actual_pixel

      delta = expected_pixel.zip(actual_pixel).map { |e, a| (e - a).abs }
      next unless delta.any? { |value| value > max_delta }

      mismatched_pixels += 1
      break if mismatched_pixels > allowed_pixels
    end

    assert_operator mismatched_pixels, :<=, allowed_pixels
  end

  def ppm_binary_data_offset(data)
    index = 0
    tokens = 0
    while index < data.bytesize && tokens < 4
      index += 1 while index < data.bytesize && data.getbyte(index).chr.match?(/\s/)
      index += 1 while index < data.bytesize && !data.getbyte(index).chr.match?(/\s/)
      tokens += 1
    end
    index += 1 while index < data.bytesize && data.getbyte(index).chr.match?(/\s/)
    index
  end
end
