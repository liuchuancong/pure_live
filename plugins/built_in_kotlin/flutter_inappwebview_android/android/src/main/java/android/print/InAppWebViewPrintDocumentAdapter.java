package android.print;

import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class InAppWebViewPrintDocumentAdapter extends PrintDocumentAdapter {
  @NonNull
  private final PrintDocumentAdapter delegate;
  @Nullable
  private final PrintDocumentAdapterCallback callback;

  public InAppWebViewPrintDocumentAdapter(@NonNull PrintDocumentAdapter delegate, @Nullable PrintDocumentAdapterCallback callback) {
    this.delegate = delegate;
    this.callback = callback;
  }

  @Override
  public void onStart() {
    this.delegate.onStart();
    if (this.callback != null) this.callback.onStart();
  }

  @Override
  public void onLayout(PrintAttributes oldAttributes, PrintAttributes newAttributes, CancellationSignal cancellationSignal, LayoutResultCallback layoutResultCallback, Bundle extras) {
    this.delegate.onLayout(oldAttributes, newAttributes, cancellationSignal, new LayoutResultCallback() {
      @Override
      public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
        layoutResultCallback.onLayoutFinished(info, changed);
        if (callback != null) callback.onLayoutFinished(info, changed);
      }

      @Override
      public void onLayoutFailed(CharSequence error) {
        layoutResultCallback.onLayoutFailed(error);
        if (callback != null) callback.onLayoutFailed(error);
      }

      @Override
      public void onLayoutCancelled() {
        layoutResultCallback.onLayoutCancelled();
        if (callback != null) callback.onLayoutCancelled();
      }
    }, extras);

    if (callback != null) callback.onLayout(oldAttributes, newAttributes, cancellationSignal, layoutResultCallback, extras);
  }

  @Override
  public void onWrite(PageRange[] pages, ParcelFileDescriptor destination, CancellationSignal cancellationSignal, WriteResultCallback writeResultCallback) {
    this.delegate.onWrite(pages, destination, cancellationSignal, new WriteResultCallback() {
      @Override
      public void onWriteFinished(PageRange[] pages) {
        writeResultCallback.onWriteFinished(pages);
        if (callback != null) callback.onWriteFinished(pages);
      }

      @Override
      public void onWriteFailed(CharSequence error) {
        writeResultCallback.onWriteFailed(error);
        if (callback != null) callback.onWriteFailed(error);
      }

      @Override
      public void onWriteCancelled() {
        writeResultCallback.onWriteCancelled();
        if (callback != null) callback.onWriteCancelled();
      }
    });
    if (callback != null) callback.onWrite(pages, destination, cancellationSignal, writeResultCallback);
  }

  @Override
  public void onFinish() {
    this.delegate.onFinish();
    if (this.callback != null) this.callback.onFinish();
  }

  public static class PrintDocumentAdapterCallback {
    public void onStart() {
      /* do nothing - stub */
    }

    public void onFinish() {
      /* do nothing - stub */
    }

    public void onLayout(PrintAttributes oldAttributes, PrintAttributes newAttributes, CancellationSignal cancellationSignal, LayoutResultCallback layoutResultCallback, Bundle extras) {
      /* do nothing - stub */
    }

    public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
      /* do nothing - stub */
    }

    public void onLayoutFailed(CharSequence error) {
      /* do nothing - stub */
    }

    public void onLayoutCancelled() {
      /* do nothing - stub */
    }

    public void onWrite(PageRange[] pages, ParcelFileDescriptor destination, CancellationSignal cancellationSignal, WriteResultCallback writeResultCallback) {
      /* do nothing - stub */
    }

    public void onWriteFinished(PageRange[] pages) {
      /* do nothing - stub */
    }

    public void onWriteFailed(CharSequence error) {
      /* do nothing - stub */
    }

    public void onWriteCancelled() {
      /* do nothing - stub */
    }
  }
}
