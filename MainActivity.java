package com.velocitygoldbot;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Button;

public class MainActivity extends Activity {
    private final int bg = Color.rgb(13, 18, 30);
    private final int panel = Color.rgb(25, 33, 49);
    private final int white = Color.rgb(245, 247, 250);
    private final int muted = Color.rgb(173, 184, 202);
    private final int accent = Color.rgb(63, 190, 151);

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(bg);
        getWindow().setNavigationBarColor(bg);

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(bg);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(20), dp(26), dp(20), dp(28));
        scroll.addView(page);

        TextView brand = text("VELOCITY", 13, accent, true);
        page.addView(brand);
        TextView title = text("Gold Bot", 31, white, true);
        page.addView(title);
        TextView subtitle = text("MT5 companion • XAUUSD", 15, muted, false);
        page.addView(subtitle);
        gap(page, 20);

        LinearLayout status = card(page);
        status.addView(text("BOT STATUS", 12, muted, true));
        status.addView(text("Not connected", 22, white, true));
        status.addView(text("This app does not connect to your MT5 account yet.", 14, muted, false));
        gap(page, 14);

        LinearLayout market = card(page);
        market.addView(text("MARKET", 12, muted, true));
        market.addView(text("Gold • XAUUSD", 21, white, true));
        market.addView(text("Strategy: EMA crossover + RSI confirmation", 14, muted, false));
        market.addView(text("Signal timeframe: M15", 14, muted, false));
        gap(page, 14);

        LinearLayout risk = card(page);
        risk.addView(text("RISK SETTINGS (EA DEFAULTS)", 12, muted, true));
        risk.addView(text("Risk per trade: 0.5%", 16, white, false));
        risk.addView(text("Daily loss lock: 2%", 16, white, false));
        risk.addView(text("Stop-loss: 1.5 × ATR", 16, white, false));
        risk.addView(text("Take-profit: 2:1 risk/reward target", 16, white, false));
        gap(page, 14);

        LinearLayout warning = card(page);
        warning.addView(text("DEMO TEST FIRST", 15, accent, true));
        warning.addView(text("No profit is guaranteed. The trading EA must run in MT5 on a compatible Windows PC or VPS. Android MT5 cannot run custom Expert Advisors directly.", 14, white, false));
        gap(page, 18);

        Button steps = new Button(this);
        steps.setText("View setup instructions");
        steps.setAllCaps(false);
        steps.setTextColor(Color.WHITE);
        steps.setBackgroundTintList(android.content.res.ColorStateList.valueOf(accent));
        page.addView(steps, new LinearLayout.LayoutParams(-1, dp(52)));
        steps.setOnClickListener(v -> showInstructions(page));

        TextView foot = text("Version 1.0 • Companion dashboard preview", 12, muted, false);
        foot.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams fp = new LinearLayout.LayoutParams(-1, -2);
        fp.topMargin = dp(22);
        page.addView(foot, fp);

        setContentView(scroll);
    }

    private void showInstructions(LinearLayout page) {
        new android.app.AlertDialog.Builder(this)
            .setTitle("How to run the trading EA")
            .setMessage("1. Use a Windows PC or compatible VPS with MT5 and MetaEditor.\\n\\n2. Copy Velocity_Gold_Bot_V1.mq5 into MQL5/Experts.\\n\\n3. Compile in MetaEditor (F7).\\n\\n4. Attach it to your broker's XAUUSD chart and keep DemoOnly enabled.\\n\\n5. Backtest and demo-test before any live use.\\n\\nThis Android app is currently a companion dashboard preview; it does not read balances, send orders, or control the EA.")
            .setPositiveButton("OK", null)
            .show();
    }

    private LinearLayout card(LinearLayout parent) {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(16), dp(15), dp(16), dp(15));
        c.setBackgroundColor(panel);
        parent.addView(c, new LinearLayout.LayoutParams(-1, -2));
        return c;
    }
    private TextView text(String s, int size, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s); t.setTextSize(size); t.setTextColor(color);
        t.setPadding(0, dp(3), 0, dp(5));
        if (bold) t.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return t;
    }
    private void gap(LinearLayout parent, int h) {
        View v = new View(this);
        parent.addView(v, new LinearLayout.LayoutParams(1, dp(h)));
    }
    private int dp(int v) {
        return (int)(v * getResources().getDisplayMetrics().density + 0.5f);
    }
}
