package com.renansantosf.aquaads;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Anúncios AdMob para o Aqua Caos: um intersticial (entre fases) e um
 * premiado (dobrar moedas, moedas grátis, skins).
 *
 * Como o jogo é infantil, todas as solicitações vão marcadas como
 * direcionadas a crianças, com classificação máxima G (livre).
 */
public class AquaAds extends GodotPlugin {
    private static final String TAG = "AquaAds";
    private static final long RETRY_MS = 30_000;

    private final Handler main = new Handler(Looper.getMainLooper());

    private String interstitialUnit = "";
    private String rewardedUnit = "";
    private volatile InterstitialAd interstitial;
    private volatile RewardedAd rewarded;
    private boolean loadingInterstitial;
    private boolean loadingRewarded;
    private boolean earned;

    public AquaAds(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "AquaAds";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("interstitial_closed"));
        signals.add(new SignalInfo("rewarded_closed", Boolean.class));
        return signals;
    }

    @UsedByGodot
    public void initialize(String interstitialId, String rewardedId) {
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        interstitialUnit = interstitialId;
        rewardedUnit = rewardedId;

        RequestConfiguration config = MobileAds.getRequestConfiguration().toBuilder()
                .setTagForChildDirectedTreatment(RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE)
                .setTagForUnderAgeOfConsent(RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE)
                .setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_G)
                .build();
        MobileAds.setRequestConfiguration(config);

        // A inicialização roda fora da thread principal para não travar o jogo.
        new Thread(() -> MobileAds.initialize(activity, status -> main.post(() -> {
            loadInterstitial();
            loadRewarded();
        }))).start();
    }

    @UsedByGodot
    public boolean isInterstitialReady() {
        return interstitial != null;
    }

    @UsedByGodot
    public boolean isRewardedReady() {
        return rewarded != null;
    }

    @UsedByGodot
    public void showInterstitial() {
        main.post(() -> {
            Activity activity = getActivity();
            InterstitialAd ad = interstitial;
            if (activity == null || ad == null) {
                emitSignal("interstitial_closed");
                loadInterstitial();
                return;
            }
            interstitial = null;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    emitSignal("interstitial_closed");
                    loadInterstitial();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    Log.w(TAG, "Intersticial não exibido: " + error.getMessage());
                    emitSignal("interstitial_closed");
                    loadInterstitial();
                }
            });
            ad.show(activity);
        });
    }

    @UsedByGodot
    public void showRewarded() {
        main.post(() -> {
            Activity activity = getActivity();
            RewardedAd ad = rewarded;
            if (activity == null || ad == null) {
                emitSignal("rewarded_closed", false);
                loadRewarded();
                return;
            }
            rewarded = null;
            earned = false;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    emitSignal("rewarded_closed", earned);
                    loadRewarded();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    Log.w(TAG, "Premiado não exibido: " + error.getMessage());
                    emitSignal("rewarded_closed", false);
                    loadRewarded();
                }
            });
            ad.show(activity, reward -> earned = true);
        });
    }

    private void loadInterstitial() {
        Activity activity = getActivity();
        if (activity == null || loadingInterstitial || interstitial != null || interstitialUnit.isEmpty()) {
            return;
        }
        loadingInterstitial = true;
        InterstitialAd.load(activity, interstitialUnit, new AdRequest.Builder().build(),
                new InterstitialAdLoadCallback() {
                    @Override
                    public void onAdLoaded(@NonNull InterstitialAd ad) {
                        loadingInterstitial = false;
                        interstitial = ad;
                    }

                    @Override
                    public void onAdFailedToLoad(@NonNull LoadAdError error) {
                        loadingInterstitial = false;
                        Log.w(TAG, "Intersticial não carregou: " + error.getMessage());
                        main.postDelayed(AquaAds.this::loadInterstitial, RETRY_MS);
                    }
                });
    }

    private void loadRewarded() {
        Activity activity = getActivity();
        if (activity == null || loadingRewarded || rewarded != null || rewardedUnit.isEmpty()) {
            return;
        }
        loadingRewarded = true;
        RewardedAd.load(activity, rewardedUnit, new AdRequest.Builder().build(),
                new RewardedAdLoadCallback() {
                    @Override
                    public void onAdLoaded(@NonNull RewardedAd ad) {
                        loadingRewarded = false;
                        rewarded = ad;
                    }

                    @Override
                    public void onAdFailedToLoad(@NonNull LoadAdError error) {
                        loadingRewarded = false;
                        Log.w(TAG, "Premiado não carregou: " + error.getMessage());
                        main.postDelayed(AquaAds.this::loadRewarded, RETRY_MS);
                    }
                });
    }
}
