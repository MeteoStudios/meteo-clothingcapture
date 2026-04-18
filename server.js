const fs = require('fs');
const path = require('path');

const resourceName = GetCurrentResourceName();
const resourcePath = GetResourcePath(resourceName);

setTimeout(() => {
    const dir = path.join(resourcePath, 'images', 'clothing');
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
}, 100);

RegisterNetEvent('meteo-clothingcapture:saveImage');
on('meteo-clothingcapture:saveImage', (imageData, category, filename) => {
    const src = global.source;

    if (!imageData) return;

    let base64Data = imageData;
    const match = imageData.match(/base64,(.+)/);
    if (match) {
        base64Data = match[1];
    }

    const buffer = Buffer.from(base64Data, 'base64');
    const filePath = path.join(resourcePath, 'images', category, filename);

    try {
        fs.writeFileSync(filePath, buffer);
        console.log(`[meteo-clothingcapture] Saved: ${filename}`);
        emitNet('meteo-clothingcapture:imageSaved', src, true, filename);
    } catch (err) {
        console.log(`[meteo-clothingcapture] Failed: ${err.message}`);
        emitNet('meteo-clothingcapture:imageSaved', src, false, filename);
    }
});
