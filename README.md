# meteo-clothingcapture

Clothing image capture tool for meteo-appearance. Captures transparent WEBP images of all clothing drawables (bag, mask, shoes, top, torso, legs) for both genders and saves them to `images/clothing/`.

## Requirements

- `screencapture` resource
- **FiveM Canary** (required, does not work on stable)
- In F8 console, run:
  ```
  allowEmptyHeadDrawable true
  ```

## Head Hiding Limitation

Some components (mask, top, bag) need the ped's head hidden to get a clean capture. GTA normally refuses to render a ped with component 0 (head) set to `-1`. To allow this, you **must** be on FiveM Canary and have `allowEmptyHeadDrawable true` set in the F8 console before starting a capture - otherwise the head will show through and ruin those captures.

## Usage

Single command that captures all 6 components (bag, mask, shoes, top, torso, legs) for the chosen gender:

```
/capture-clothing [male|female|all] [component]
```

Examples:
- `/capture-clothing all` - captures every drawable for both genders
- `/capture-clothing male` - only male
- `/capture-clothing female top` - only female tops

Press `Backspace` during capture to cancel.

Images are saved to `meteo-clothingcapture/images/clothing/` using the filename format `{gender}_{component}_{drawable}.webp` (e.g. `male_top_15.webp`).

## Installing images to meteo-appearance

1. Delete every existing image inside `meteo-appearance/web/build/images/clothing/`
2. Copy all files from `meteo-clothingcapture/images/clothing/` into `meteo-appearance/web/build/images/clothing/`

meteo-appearance looks up clothing images by the exact filename pattern used here, so no renaming is needed.
