// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2026 Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "d3d11_renderer.h"

#include <iostream>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

int D3D11Renderer::instance_count_ = 0;

D3D11Renderer::D3D11Renderer(int32_t width, int32_t height,
                             IDXGIAdapter* flutter_adapter)
    : width_(width), height_(height) {
  if (!CreateD3D11Device(flutter_adapter)) {
    throw std::runtime_error("Unable to create Direct3D 11 device.");
  }
  if (!CreateMailbox()) {
    throw std::runtime_error("Unable to create mailbox swap chain.");
  }
  instance_count_++;
}

D3D11Renderer::~D3D11Renderer() {
  mailbox_swap_chain_.Reset();
  d3d_11_device_context_.Reset();
  d3d_11_device_.Reset();
  instance_count_--;
}

void D3D11Renderer::SetSize(int32_t width, int32_t height) {
  if (width == width_ && height == height_) return;
  width_ = width;
  height_ = height;
  if (mailbox_swap_chain_) {
    const HRESULT hr = mailbox_swap_chain_->Resize(width_, height_);
    if (FAILED(hr)) {
      std::cout << "media_kit: D3D11Renderer: Mailbox resize failed (hr=0x"
                << std::hex << hr << std::dec << ")" << std::endl;
    }
  }
}

void D3D11Renderer::ProducerCommit() {
  if (mailbox_swap_chain_) {
    mailbox_swap_chain_->ProducerCommit();
  }
}

HANDLE D3D11Renderer::ConsumerAcquire() {
  if (mailbox_swap_chain_) {
    return mailbox_swap_chain_->ConsumerAcquire();
  }
  return nullptr;
}

HANDLE D3D11Renderer::ReadHandleSnapshot() const {
  if (mailbox_swap_chain_) {
    return mailbox_swap_chain_->ReadHandleSnapshot();
  }
  return nullptr;
}

bool D3D11Renderer::CreateD3D11Device(IDXGIAdapter* flutter_adapter) {
  if (d3d_11_device_) return true;

  const D3D_FEATURE_LEVEL feature_levels[] = {
      D3D_FEATURE_LEVEL_11_1,
      D3D_FEATURE_LEVEL_11_0,
      D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0,
      D3D_FEATURE_LEVEL_9_3,
  };

  Microsoft::WRL::ComPtr<IDXGIAdapter> adapter(flutter_adapter);
  D3D_DRIVER_TYPE driver_type = D3D_DRIVER_TYPE_UNKNOWN;

  if (!adapter) {
    if (Utils::IsWindows10RTMOrGreater()) {
      driver_type = D3D_DRIVER_TYPE_HARDWARE;
    } else {
      Microsoft::WRL::ComPtr<IDXGIFactory> dxgi;
      ::CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&dxgi);
      if (dxgi) {
        dxgi->EnumAdapters(0, &adapter);
      }
    }
  } else {
    std::cout << "media_kit: D3D11Renderer: Using Flutter's DXGI adapter."
              << std::endl;
  }

  const HRESULT hr = ::D3D11CreateDevice(
      adapter.Get(), driver_type, nullptr,
      D3D11_CREATE_DEVICE_BGRA_SUPPORT,
      feature_levels, static_cast<UINT>(std::size(feature_levels)),
      D3D11_SDK_VERSION, d3d_11_device_.GetAddressOf(), nullptr,
      d3d_11_device_context_.GetAddressOf());

  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: D3D11CreateDevice failed (hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device;
  if (SUCCEEDED(d3d_11_device_->QueryInterface(__uuidof(IDXGIDevice),
                                               (void**)&dxgi_device)) &&
      dxgi_device) {
    dxgi_device->SetGPUThreadPriority(5);
  }

  const auto level = d3d_11_device_->GetFeatureLevel();
  std::cout << "media_kit: D3D11Renderer: Direct3D Feature Level: "
            << (static_cast<unsigned>(level) >> 12) << "_"
            << ((static_cast<unsigned>(level) >> 8) & 0xfu) << std::endl;

  return true;
}

bool D3D11Renderer::CreateMailbox() {
  MailboxSwapChain* raw = nullptr;
  const HRESULT hr =
      MailboxSwapChain::Create(d3d_11_device_.Get(), width_, height_, &raw);
  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: MailboxSwapChain::Create failed "
                 "(hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }
  mailbox_swap_chain_.Attach(raw);
  return true;
}