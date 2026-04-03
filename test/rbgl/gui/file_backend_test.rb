# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"

class FileBackendTest < Test::Unit::TestCase
  setup do
    @tmpdir = Dir.mktmpdir
    @backend = RBGL::GUI::FileBackend.new(10, 10, "Test", format: :ppm, output_dir: @tmpdir)
    @fb = RBGL::Engine::Framebuffer.new(10, 10)
  end

  teardown do
    FileUtils.rm_rf(@tmpdir)
  end

  test "initializes with default format and output_dir" do
    backend = RBGL::GUI::FileBackend.new(640, 480)
    assert_equal 640, backend.width
    assert_equal 480, backend.height
  end

  test "should_close? returns false initially" do
    assert_false @backend.should_close?
  end

  test "close sets should_close to true" do
    @backend.close
    assert_true @backend.should_close?
  end

  test "poll_events returns an empty array" do
    assert_equal [], @backend.poll_events
  end

  test "present creates PPM file" do
    @backend.present(@fb)
    assert File.exist?(File.join(@tmpdir, "frame_00000.ppm"))
  end

  test "present increments frame count" do
    @backend.present(@fb)
    @backend.present(@fb)
    assert File.exist?(File.join(@tmpdir, "frame_00000.ppm"))
    assert File.exist?(File.join(@tmpdir, "frame_00001.ppm"))
  end

  test "present with binary PPM format" do
    backend = RBGL::GUI::FileBackend.new(10, 10, "Test", format: :ppm_binary, output_dir: @tmpdir)
    backend.present(@fb)
    assert File.exist?(File.join(@tmpdir, "frame_00000.ppm_binary"))
  end

  test "present with BMP format" do
    backend = RBGL::GUI::FileBackend.new(10, 10, "Test", format: :bmp, output_dir: @tmpdir)
    backend.present(@fb)
    file = File.join(@tmpdir, "frame_00000.bmp")
    assert File.exist?(file)

    # Verify BMP header
    content = File.binread(file)
    assert_equal "BM", content[0, 2]
  end

  test "set_max_frames limits frames" do
    @backend.set_max_frames(2)
    @backend.present(@fb)
    assert_false @backend.should_close?
    @backend.present(@fb)
    assert_true @backend.should_close?
  end
end
