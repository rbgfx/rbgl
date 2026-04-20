# frozen_string_literal: true

require_relative "../../test_helper"
require "json"
require "rbgl/cli/doctor"
require "stringio"

class RBGL::CLI::DoctorTest < Test::Unit::TestCase
  private

  def build_doctor(json:, env:, platform:, checks: {})
    output = StringIO.new
    doctor = RBGL::CLI::Doctor.new(
      json: json,
      io: output,
      env: env,
      platform: platform,
      checks: checks
    )
    [doctor, output]
  end

  def mock_checks(overrides = {})
    defaults = {
      file_backend: ->(_doctor, _env, _platform) { { available: true, path: "/tmp/mock-output" } },
      wayland: ->(_doctor, env, _platform) {
        { display: env["WAYLAND_DISPLAY"], display_available: !!env["WAYLAND_DISPLAY"], require_ok: true }
      },
      x11: ->(_doctor, env, _platform) {
        { display: env["DISPLAY"], display_available: !!env["DISPLAY"], require_ok: true }
      },
      cocoa: ->(_doctor, _env, platform) { { platform: platform, supported: platform.include?("darwin"), require_ok: false } },
      rlsl: ->(_doctor, _env, _platform) { { require_ok: true, version: "0.1.1" } }
    }.merge(overrides)
    defaults
  end

  test "outputs readable text report" do
    doctor, output = build_doctor(
      json: false,
      env: { "DISPLAY" => ":0", "WAYLAND_DISPLAY" => "wayland-0" },
      platform: "linux",
      checks: mock_checks
    )

    assert_equal 0, doctor.run
    assert_true output.string.include?("RBGL version:")
    assert_true output.string.include?("Wayland:")
    assert_true output.string.include?("X11:")
    assert_true output.string.include?("RLSL:")
  end

  test "outputs valid JSON report" do
    doctor, output = build_doctor(
      json: true,
      env: { "DISPLAY" => ":0" },
      platform: "x86_64-linux",
      checks: mock_checks
    )

    assert_equal 0, doctor.run
    payload = JSON.parse(output.string)

    assert_equal RBGL::VERSION, payload["rbgl_version"]
    assert_equal "x86_64-linux", payload["platform"]
    assert_true payload["x11"]["require_ok"]
    assert_equal "0.1.1", payload["rlsl"]["version"]
  end

  test "returns fallback data when a check fails" do
    doctor, output = build_doctor(
      json: true,
      env: {},
      platform: "linux",
      checks: mock_checks(
        rlsl: ->(_doctor, _env, _platform) { raise "network unavailable" }
      )
    )

    assert_equal 0, doctor.run
    payload = JSON.parse(output.string)

    assert_false payload["rlsl"]["available"]
    assert_true payload["rlsl"]["error"].include?("RuntimeError")
  end

  test "default checks can invoke private implementations" do
    doctor, = build_doctor(json: true, env: {}, platform: "linux")

    result = RBGL::CLI::Doctor.default_checks.fetch(:cocoa).call(doctor, {}, "linux")

    assert_equal({ platform: "linux", supported: false }, result)
  end
end
