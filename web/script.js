let config = {
    greenThreshold: 120,
    greenDiff: 40,
    outputSize: 512,
    outputFormat: 'webp',
    cropBottom: 80,
    cropRight: 80
};

function preCropImage(canvas, ctx) {
    const originalWidth = canvas.width;
    const originalHeight = canvas.height;

    const cropWidth = originalWidth - config.cropRight;
    const cropHeight = originalHeight - config.cropBottom;

    const croppedData = ctx.getImageData(0, 0, cropWidth, cropHeight);

    canvas.width = cropWidth;
    canvas.height = cropHeight;

    ctx.putImageData(croppedData, 0, 0);

    return ctx.getImageData(0, 0, cropWidth, cropHeight);
}

function removeGreenBackground(imageData) {
    const data = imageData.data;
    const threshold = config.greenThreshold;
    const diff = config.greenDiff;

    for (let i = 0; i < data.length; i += 4) {
        const red = data[i];
        const green = data[i + 1];
        const blue = data[i + 2];
        const alpha = data[i + 3];

        const greenDiff = green - Math.max(red, blue);

        if (green > threshold && greenDiff > diff) {
            const proximity = Math.min((greenDiff - diff) / 80, 1);

            data[i + 3] = Math.max(0, Math.floor(alpha * (1 - proximity)));

            data[i + 1] = Math.max(0, Math.floor(green * (1 - proximity * 0.5)));

            data[i] = Math.min(255, red + Math.floor(green * 0.1 * proximity));
            data[i + 2] = Math.min(255, blue + Math.floor(green * 0.1 * proximity));
        }
    }

    return imageData;
}

function findBoundingBox(imageData) {
    const data = imageData.data;
    const width = imageData.width;
    const height = imageData.height;

    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;
    let opaquePixelCount = 0;

    for (let i = 0; i < data.length; i += 4) {
        if (data[i + 3] > 10) {
            const pixelIndex = i / 4;
            const x = pixelIndex % width;
            const y = Math.floor(pixelIndex / width);

            minX = Math.min(minX, x);
            minY = Math.min(minY, y);
            maxX = Math.max(maxX, x);
            maxY = Math.max(maxY, y);
            opaquePixelCount++;
        }
    }

    if (minX >= maxX || minY >= maxY) {
        return null;
    }

    const boxWidth = maxX - minX + 1;
    const boxHeight = maxY - minY + 1;
    const boxArea = boxWidth * boxHeight;

    if (boxArea < 100 || opaquePixelCount < 50) {
        console.log('Skipping empty/artifact image - box area:', boxArea, 'opaque pixels:', opaquePixelCount);
        return null;
    }

    return { minX, minY, maxX, maxY };
}

function cropAndScale(canvas, ctx, bounds) {
    if (!bounds) {
        return null;
    }

    const { minX, minY, maxX, maxY } = bounds;
    const width = maxX - minX + 1;
    const height = maxY - minY + 1;

    const croppedData = ctx.getImageData(minX, minY, width, height);

    const squareSize = config.outputSize;
    const squareCanvas = document.createElement('canvas');
    const squareCtx = squareCanvas.getContext('2d');

    squareCanvas.width = squareSize;
    squareCanvas.height = squareSize;

    squareCtx.clearRect(0, 0, squareSize, squareSize);

    const maxDim = Math.max(width, height);
    const scale = Math.min(squareSize / maxDim, 1);
    const scaledWidth = Math.floor(width * scale);
    const scaledHeight = Math.floor(height * scale);

    const tempCanvas = document.createElement('canvas');
    const tempCtx = tempCanvas.getContext('2d');
    tempCanvas.width = width;
    tempCanvas.height = height;
    tempCtx.putImageData(croppedData, 0, 0);

    const offsetX = Math.floor((squareSize - scaledWidth) / 2);
    const offsetY = Math.floor((squareSize - scaledHeight) / 2);

    squareCtx.drawImage(tempCanvas, 0, 0, width, height, offsetX, offsetY, scaledWidth, scaledHeight);

    return squareCanvas;
}

function processImage(base64Image, callback) {
    const img = new Image();

    img.onload = function() {
        const canvas = document.getElementById('processCanvas');
        const ctx = canvas.getContext('2d');

        canvas.width = img.width;
        canvas.height = img.height;

        ctx.drawImage(img, 0, 0);

        let imageData = preCropImage(canvas, ctx);

        imageData = removeGreenBackground(imageData);
        ctx.putImageData(imageData, 0, 0);

        const bounds = findBoundingBox(imageData);
        const resultCanvas = cropAndScale(canvas, ctx, bounds);

        if (resultCanvas) {
            const mimeType = config.outputFormat === 'png' ? 'image/png' : 'image/webp';
            const quality = config.outputFormat === 'png' ? undefined : 0.9;
            const imageData = resultCanvas.toDataURL(mimeType, quality);
            callback(imageData);
        } else {
            callback(null);
        }
    };

    img.onerror = function() {
        callback(null);
    };

    let imageSrc = base64Image;
    if (!base64Image.startsWith('data:')) {
        imageSrc = 'data:image/png;base64,' + base64Image;
    }

    img.src = imageSrc;
}

function showProgress(text, current, total) {
    const container = document.getElementById('progress-container');
    const textEl = document.getElementById('progress-text');
    const fillEl = document.getElementById('progress-fill');

    textEl.textContent = text + (total > 0 ? ` (${current}/${total})` : '');
    fillEl.style.width = total > 0 ? `${(current / total) * 100}%` : '0%';
    container.classList.add('show');
}

function hideProgress() {
    document.getElementById('progress-container').classList.remove('show');
}

function showNotification(message, type = 'info') {
    const container = document.getElementById('notifications');
    const notif = document.createElement('div');
    notif.className = `notification ${type}`;
    notif.textContent = message;

    container.appendChild(notif);

    setTimeout(() => {
        notif.style.opacity = '0';
        notif.style.transform = 'translateY(50px)';
        setTimeout(() => notif.remove(), 300);
    }, 3000);
}

function showControls(title, controls) {
    const container = document.getElementById('controls-container');
    const titleEl = document.getElementById('controls-title');
    const gridEl = document.getElementById('controls-grid');

    titleEl.textContent = title;
    gridEl.innerHTML = '';

    controls.forEach(ctrl => {
        const item = document.createElement('div');
        item.className = 'control-item';
        item.innerHTML = `
            <span class="control-key">${ctrl.key}</span>
            <span class="control-desc">${ctrl.desc}</span>
        `;
        gridEl.appendChild(item);
    });

    container.classList.add('show');
}

function hideControls() {
    document.getElementById('controls-container').classList.remove('show');
}

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'updateConfig':
            if (data.config) {
                config.greenThreshold = data.config.greenThreshold || 120;
                config.greenDiff = data.config.greenDiff || 40;
                config.outputSize = data.config.outputSize || 512;
                config.outputFormat = data.config.outputFormat || 'webp';
                config.cropBottom = data.config.cropBottom || 80;
                config.cropRight = data.config.cropRight || 80;
            }
            break;

        case 'processImage':
            processImage(data.image, function(processedImage) {
                fetch(`https://${GetParentResourceName()}/imageProcessed`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        success: processedImage !== null,
                        image: processedImage,
                        filename: data.filename,
                        category: data.category
                    })
                });
            });
            break;

        case 'showProgress':
            showProgress(data.text, data.current, data.total);
            break;

        case 'hideProgress':
            hideProgress();
            break;

        case 'notification':
            showNotification(data.message, data.type || 'info');
            break;

        case 'showControls':
            showControls(data.title, data.controls);
            break;

        case 'hideControls':
            hideControls();
            break;
    }
});
