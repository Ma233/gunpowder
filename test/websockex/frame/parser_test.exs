defmodule WebSockex.Frame.ParserTest do
  use ExUnit.Case, async: true
  alias WebSockex.Frame.Parser

  @close_frame <<1::1, 0::3, 8::4, 0::1, 0::7>>
  @ping_frame <<1::1, 0::3, 9::4, 0::1, 0::7>>
  @pong_frame <<1::1, 0::3, 10::4, 0::1, 0::7>>
  @close_frame_with_payload <<1::1, 0::3, 8::4, 0::1, 7::7, 1000::16, "Hello">>
  @ping_frame_with_payload <<1::1, 0::3, 9::4, 0::1, 5::7, "Hello">>
  @pong_frame_with_payload <<1::1, 0::3, 10::4, 0::1, 5::7, "Hello">>

  @binary :erlang.term_to_binary :hello

  describe "parse_frame" do
    test "returns incomplete when the frame is less than 16 bits" do
      <<part::10, _::bits>> = @ping_frame
      assert Parser.parse_frame(<<part>>) == :incomplete
    end
    test "handles incomplete frames with complete headers" do
      frame = <<1::1, 0::3, 1::4, 0::1, 5::7, "Hello"::utf8>>

      <<part::bits-size(20), rest::bits>> = frame
      assert Parser.parse_frame(part) == :incomplete

      assert Parser.parse_frame(<<part::bits, rest::bits>>) ==
        {:ok, {:text, "Hello"}, <<>>}
    end
    test "handles incomplete large frames" do
      len = 0x5555
      frame = <<1::1, 0::3, 1::4, 0::1, 126::7, len::16, 0::500*8, "Hello">>
      assert Parser.parse_frame(frame) == :incomplete
    end
    test "handles incomplete very large frame" do
      len = 0x5FFFF
      frame = <<1::1, 0::3, 1::4, 0::1, 127::7, len::64, 0::1000*8, "Hello">>
      assert Parser.parse_frame(frame) == :incomplete
    end

    test "returns overflow buffer" do
      <<first::bits-size(16), overflow::bits-size(14), rest::bitstring>> =
        <<@ping_frame, @ping_frame_with_payload>>
      payload = <<first::bits, overflow::bits>>
      assert Parser.parse_frame(payload) == {:ok, :ping, overflow}
      assert Parser.parse_frame(<<overflow::bits, rest::bits>>) ==
        {:ok, {:ping, "Hello"}, <<>>}
    end

    test "parses a close frame" do
      assert Parser.parse_frame(@close_frame) == {:ok, :close, <<>>}
    end
    test "parses a ping frame" do
      assert Parser.parse_frame(@ping_frame) == {:ok, :ping, <<>>}
    end
    test "parses a pong frame" do
      assert Parser.parse_frame(@pong_frame) == {:ok, :pong, <<>>}
    end

    test "parses a close frame with a payload" do
      assert Parser.parse_frame(@close_frame_with_payload) ==
        {:ok, {:close, 1000, "Hello"}, <<>>}
    end
    test "parses a ping frame with a payload" do
      assert Parser.parse_frame(@ping_frame_with_payload) ==
        {:ok, {:ping, "Hello"}, <<>>}
    end
    test "parses a pong frame with a payload" do
      assert Parser.parse_frame(@pong_frame_with_payload) ==
        {:ok, {:pong, "Hello"}, <<>>}
    end

    test "parses a text frame" do
      frame = <<1::1, 0::3, 1::4, 0::1, 5::7, "Hello"::utf8>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:text, "Hello"}, <<>>}
    end
    test "parses a large text frame" do
      string = <<0::5000*8, "Hello">>
      len = byte_size(string)
      frame = <<1::1, 0::3, 1::4, 0::1, 126::7, len::16, string::binary>>
      assert Parser.parse_frame(frame) == {:ok, {:text, string}, <<>>}
    end
    test "parses a very large text frame" do
      string = <<0::80_000*8, "Hello">>
      len = byte_size(string)
      frame = <<1::1, 0::3, 1::4, 0::1, 127::7, len::64, string::binary>>
      assert Parser.parse_frame(frame) == {:ok, {:text, string}, <<>>}
    end

    test "parses a binary frame" do
      len = byte_size @binary
      frame = <<1::1, 0::3, 2::4, 0::1, len::7, @binary::bytes>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:binary, @binary}, <<>>}
    end
    test "parses a large binary frame" do
      binary = <<0::5000*8, @binary::binary>>
      len = byte_size binary
      frame = <<1::1, 0::3, 2::4, 0::1, 126::7, len::16, binary::binary>>
      assert Parser.parse_frame(frame) == {:ok, {:binary, binary}, <<>>}
    end
    test "parses a very large binary frame" do
      binary = <<0::80_000*8, @binary::binary>>
      len = byte_size binary
      frame = <<1::1, 0::3, 2::4, 0::1, 127::7, len::64, binary::binary>>
      assert Parser.parse_frame(frame) == {:ok, {:binary, binary}, <<>>}
    end

    test "parses a text fragment frame" do
      frame = <<0::1, 0::3, 1::4, 0::1, 5::7, "Hello"::utf8>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:fragment, :text, "Hello"}, <<>>}
    end
    test "parses a large text fragment frame" do
      string = <<0::5000*8, "Hello">>
      len = byte_size(string)
      frame = <<0::1, 0::3, 1::4, 0::1, 126::7, len::16, string::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:fragment, :text, string}, <<>>}
    end
    test "parses a very large text fragment frame" do
      string = <<0::80_000*8, "Hello">>
      len = byte_size(string)
      frame = <<0::1, 0::3, 1::4, 0::1, 127::7, len::64, string::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:fragment, :text, string}, <<>>}
    end

    test "parses a binary fragment frame" do
      len = byte_size @binary
      frame = <<0::1, 0::3, 2::4, 0::1, len::7, @binary::bytes>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:fragment, :binary, @binary}, <<>>}
    end
    test "parses a large binary fragment frame" do
      binary = <<0::5000*8, @binary::binary>>
      len = byte_size binary
      frame = <<0::1, 0::3, 2::4, 0::1, 126::7, len::16, binary::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:fragment, :binary, binary}, <<>>}
    end
    test "parses a very large binary fragment frame" do
      binary = <<0::80_000*8, @binary::binary>>
      len = byte_size binary
      frame = <<0::1, 0::3, 2::4, 0::1, 127::7, len::64, binary::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:fragment, :binary, binary}, <<>>}
    end

    test "parses a continuation frame in a fragmented segment" do
      frame = <<0::1, 0::3, 0::4, 0::1, 5::7, "Hello"::utf8>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:continuation, "Hello"}, <<>>}
    end
    test "parses a large continuation frame in a fragmented segment" do
      string = <<0::5000*8, "Hello">>
      len = byte_size(string)
      frame = <<0::1, 0::3, 0::4, 0::1, 126::7, len::16, string::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:continuation, string}, <<>>}
    end
    test "parses a very large continuation frame in a fragmented segment" do
      string = <<0::80_000*8, "Hello">>
      len = byte_size(string)
      frame = <<0::1, 0::3, 0::4, 0::1, 127::7, len::64, string::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:continuation, string}, <<>>}
    end

    test "parses a finish frame in a fragmented segment" do
      frame = <<1::1, 0::3, 0::4, 0::1, 5::7, "Hello"::utf8>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:finish, "Hello"}, <<>>}
    end
    test "parses a large finish frame in a fragmented segment" do
      string = <<0::5000*8, "Hello">>
      len = byte_size(string)
      frame = <<1::1, 0::3, 0::4, 0::1, 126::7, len::16, string::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:finish, string}, <<>>}
    end
    test "parses a very large finish frame in a fragmented segment" do
      string = <<0::80_000*8, "Hello">>
      len = byte_size(string)
      frame = <<1::1, 0::3, 0::4, 0::1, 127::7, len::64, string::binary>>
      assert Parser.parse_frame(frame) ==
        {:ok, {:finish, string}, <<>>}
    end

    test "nonfin control frame returns an error" do
      frame = <<0::1, 0::3, 9::4, 0::1, 0::7>>
      assert Parser.parse_frame(frame) ==
        {:error,
          %WebSockex.FrameError{reason: :nonfin_control_frame,
                                opcode: :ping,
                                buffer: frame}}
    end
    test "large control frames return an error" do
      error = %WebSockex.FrameError{reason: :control_frame_too_large,
                                    opcode: :ping}

      frame = <<1::1, 0::3, 9::4, 0::1, 126::7>>
      assert Parser.parse_frame(frame) ==
        {:error, %{error | buffer: frame}}

      frame = <<1::1, 0::3, 9::4, 0::1, 127::7>>
      assert Parser.parse_frame(frame) ==
        {:error, %{error | buffer: frame}}
    end

    test "close frames with data must have atleast 2 bytes of data" do
      frame = <<1::1, 0::3, 8::4, 0::1, 1::7, 0::8>>
      assert Parser.parse_frame(frame) ==
        {:error,
          %WebSockex.FrameError{reason: :close_with_single_byte_payload,
                                opcode: :close,
                                buffer: frame}}
    end

    test "Close Frames with improper close codes return an error" do
      frame = <<1::1, 0::3, 8::4, 0::1, 7::7, 5000::16, "Hello">>
      assert Parser.parse_frame(frame) ==
        {:error, %WebSockex.FrameError{reason: :invalid_close_code,
                                       opcode: :close,
                                       buffer: frame}}
    end

    test "Text Frames check for valid UTF-8" do
      frame = <<1::1, 0::3, 1::4, 0::1, 7::7, 0xFFFF::16, "Hello"::utf8>>
      assert Parser.parse_frame(frame) ==
        {:error, %WebSockex.FrameError{reason: :invalid_utf8,
                                       opcode: :text,
                                       buffer: frame}}
    end

    test "Close Frames with payloads check for valid UTF-8" do
      frame = <<1::1, 0::3, 8::4, 0::1, 9::7, 1000::16, 0xFFFF::16, "Hello"::utf8>>
      assert Parser.parse_frame(frame) ==
        {:error, %WebSockex.FrameError{reason: :invalid_utf8,
                                       opcode: :close,
                                       buffer: frame}}
    end
  end

  describe "parse_fragment" do
    test "Errors with two fragment starts" do
      frame0 = {:fragment, :text, "Hello"}
      frame1 = {:fragment, :text, "Goodbye"}
      assert Parser.parse_fragment(frame0, frame1) ==
        {:error,
          %WebSockex.FragmentParseError{reason: :two_start_frames,
                                        fragment: frame0,
                                        continuation: frame1}}
    end

    test "Applies continuation to a text fragment" do
      frame = <<0xFFFF::16, "Hello"::utf8>>
      <<part::binary-size(4), rest::binary>> = frame
      assert Parser.parse_fragment({:fragment, :text, part}, {:continuation, rest}) ==
        {:ok, {:fragment, :text, frame}}
    end
    test "Finishes a text fragment" do
      frame0 = {:fragment, :text, "Hel"}
      frame1 = {:finish, "lo"}
      assert Parser.parse_fragment(frame0, frame1) ==
        {:ok, {:text, "Hello"}}
    end
    test "Errors with invalid utf-8 in a text fragment" do
      frame = <<0xFFFF::16, "Hello"::utf8>>
      <<part::binary-size(4), rest::binary>> = frame
      assert Parser.parse_fragment({:fragment, :text, part}, {:finish, rest}) ==
        {:error,
          %WebSockex.FrameError{reason: :invalid_utf8,
                                opcode: :text,
                                buffer: frame}}
    end

    test "Applies a continuation to a binary fragment" do
      <<part::binary-size(3), rest::binary>> = @binary
      assert Parser.parse_fragment({:fragment, :binary, part}, {:continuation, rest}) ==
        {:ok, {:fragment, :binary, @binary}}
    end
    test "Finishes a binary fragment" do
      <<part::binary-size(3), rest::binary>> = @binary
      assert Parser.parse_fragment({:fragment, :binary, part}, {:finish, rest}) ==
        {:ok, {:binary, @binary}}
    end
  end
end