// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef D3D11_RENDERER_H_
#define D3D11_RENDERER_H_

#include <Windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <dxgi1_2.h>
#include <wrl.h>

#include <cstdint>
#include <iostream>

#include "mailbox_swap_chain.h"
#include "utils.h"

// D3D11Renderer creates a D3D11 device and owns a MailboxSwapChain that
// implements the lock-free triple-buffer mailbox between the libmpv rendering
// thread (producer) and Flutter's render thread (consumer).
//
// The MailboxSwapChain is passed directly to mpv as the IDXGISwapChain* in
// mpv_dxgi_init_params.  mpv calls GetBuffer(0, ...) to obtain a render
// target and submits GPU work into it.  The plugin then calls
// ProducerCommit(), which (a) signals a fence on the submitted work,
// (b) non-blockingly checks the *previous* frame's fence and, if already
// GPU-complete, promotes it to latest_completed_slot_, and (c) atomically
// publishes write_slot_ as the new pending frame.  Flutter's
// GpuSurfaceTexture callback calls ConsumerAcquire() — a single acquire
// load of latest_completed_slot_ — to receive the DXGI shared HANDLE of
// the newest confirmed frame, with no copy, no flush, and no OS lock.
class D3D11Renderer {
 public:
  int32_t width() const { return width_; }
  int32_t height() const { return height_; }

  // Raw device pointer used by VideoOutput to populate mpv_dxgi_init_params.
  ID3D11Device* device() const { return d3d_11_device_.Get(); }

  // IDXGISwapChain* facade backed by MailboxSwapChain.
  // Passed to mpv as mpv_dxgi_init_params::swapchain (void*).
  IDXGISwapChain* swap_chain() const { return mailbox_swap_chain_.Get(); }

  // |flutter_adapter| is the IDXGIAdapter* returned by
  // FlutterDesktopViewGetGraphicsAdapter.  When non-null the D3D11 device is
  // created on exactly that adapter so the plugin always shares the same GPU
  // as the Flutter compositor.  Pass nullptr to fall back to the legacy
  // heuristic (hardware default on Win10+, adapter 0 on older Windows).
  explicit D3D11Renderer(int32_t width, int32_t height,
                         IDXGIAdapter* flutter_adapter = nullptr);
  ~D3D11Renderer();

  // Recreates the three mailbox slots at the new dimensions.
  // Must be called from the producer thread only.
  void SetSize(int32_t width, int32_t height);

  // Called from the producer thread (mpv thread pool) after
  // mpv_render_context_render returns.  Signals the frame fence, then
  // non-blockingly attempts to promote the previous pending frame to
  // latest_completed_slot_, and finally publishes the new pending frame.
  void ProducerCommit();

  // Called from the consumer thread (Flutter GpuSurfaceTexture callback).
  // Returns the DXGI shared HANDLE of the most recent fence-confirmed frame
  // via a single atomic load — no fence poll, no flush, no stall.
  HANDLE ConsumerAcquire();

  // Returns the DXGI shared HANDLE for the current read slot without
  // advancing mailbox state.  Used once during texture registration before
  // the consumer thread starts.
  HANDLE ReadHandleSnapshot() const;

 private:
  bool CreateD3D11Device(IDXGIAdapter* flutter_adapter);
  bool CreateMailbox();

  int32_t width_ = 1;
  int32_t height_ = 1;

  Microsoft::WRL::ComPtr<ID3D11Device> d3d_11_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> d3d_11_device_context_;

  Microsoft::WRL::ComPtr<MailboxSwapChain> mailbox_swap_chain_;

  static int instance_count_;
};

#endif  // D3D11_RENDERER_H_