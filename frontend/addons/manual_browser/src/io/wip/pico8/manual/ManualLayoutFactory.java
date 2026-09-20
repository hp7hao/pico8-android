package io.wip.pico8.manual;

import android.view.ViewGroup;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.LinearLayout;

public final class ManualLayoutFactory {
    private ManualLayoutFactory() {}

    public static ViewGroup.LayoutParams root(int width, int height) {
        return new ViewGroup.LayoutParams(width, height);
    }

    public static LinearLayout.LayoutParams linear(int width, int height) {
        return new LinearLayout.LayoutParams(width, height);
    }

    public static LinearLayout.LayoutParams weighted(int width, int height, float weight) {
        return new LinearLayout.LayoutParams(width, height, weight);
    }

    public static FrameLayout.LayoutParams frame(int width, int height, int gravity) {
        return new FrameLayout.LayoutParams(width, height, gravity);
    }

    public static void configureWebView(WebView webView) {
        webView.setWebViewClient(new WebViewClient());
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(false);
        settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setBuiltInZoomControls(true);
        settings.setDisplayZoomControls(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setTextZoom(115);
    }
}
