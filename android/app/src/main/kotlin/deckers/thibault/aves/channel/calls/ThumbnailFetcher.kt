package deckers.thibault.aves.channel.calls

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import androidx.annotation.RequiresApi
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.request.RequestOptions
import com.bumptech.glide.signature.ObjectKey
import deckers.thibault.aves.decoder.VideoThumbnail
import deckers.thibault.aves.utils.BitmapUtils.applyExifOrientation
import deckers.thibault.aves.utils.BitmapUtils.getBytes
import deckers.thibault.aves.utils.MimeTypes
import deckers.thibault.aves.utils.MimeTypes.isVideo
import deckers.thibault.aves.utils.MimeTypes.needRotationAfterContentResolverThumbnail
import deckers.thibault.aves.utils.MimeTypes.needRotationAfterGlide
import io.flutter.plugin.common.MethodChannel
import org.beyka.tiffbitmapfactory.TiffBitmapFactory

class ThumbnailFetcher internal constructor(
    private val context: Context,
    uri: String,
    private val mimeType: String,
    private val dateModifiedSecs: Long,
    private val rotationDegrees: Int,
    private val isFlipped: Boolean,
    width: Int?,
    height: Int?,
    private val defaultSize: Int,
    private val result: MethodChannel.Result,
) {
    val uri: Uri = Uri.parse(uri)
    val width: Int = if (width?.takeIf { it > 0 } != null) width else defaultSize
    val height: Int = if (height?.takeIf { it > 0 } != null) height else defaultSize

    fun fetch() {
        var bitmap: Bitmap? = null
        var recycle = true
        var exception: Exception? = null

        try {
            if (mimeType == MimeTypes.TIFF) {
                bitmap = getTiff()
            } else if ((width == defaultSize || height == defaultSize) && !isFlipped) {
                // Fetch low quality thumbnails when size is not specified.
                // As of Android R, the Media Store content resolver may return a thumbnail
                // that is automatically rotated according to EXIF orientation, but not flipped,
                // so we skip this step for flipped entries.
                bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) getByResolver() else getByMediaStore()
            }
        } catch (e: Exception) {
            exception = e
        }

        // fallback if the native methods failed or for higher quality thumbnails
        if (bitmap == null) {
            try {
                bitmap = getByGlide()
                recycle = false
            } catch (e: Exception) {
                exception = e
            }
        }

        if (bitmap != null) {
            result.success(bitmap.getBytes(MimeTypes.canHaveAlpha(mimeType), recycle = recycle))
        } else {
            var errorDetails: String? = exception?.message
            if (errorDetails?.isNotEmpty() == true) {
                errorDetails = errorDetails.split("\n".toRegex(), 2).first()
            }
            result.error("getThumbnail-null", "failed to get thumbnail for uri=$uri", errorDetails)
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.Q)
    private fun getByResolver(): Bitmap? {
        val resolver = context.contentResolver
        var bitmap: Bitmap? = resolver.loadThumbnail(uri, Size(width, height), null)
        if (needRotationAfterContentResolverThumbnail(mimeType)) {
            bitmap = applyExifOrientation(context, bitmap, rotationDegrees, isFlipped)
        }
        return bitmap
    }

    private fun getByMediaStore(): Bitmap? {
        val contentId = ContentUris.parseId(uri)
        val resolver = context.contentResolver
        return if (isVideo(mimeType)) {
            @Suppress("DEPRECATION")
            MediaStore.Video.Thumbnails.getThumbnail(resolver, contentId, MediaStore.Video.Thumbnails.MINI_KIND, null)
        } else {
            @Suppress("DEPRECATION")
            var bitmap = MediaStore.Images.Thumbnails.getThumbnail(resolver, contentId, MediaStore.Images.Thumbnails.MINI_KIND, null)
            // from Android Q, returned thumbnail is already rotated according to EXIF orientation
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && bitmap != null) {
                bitmap = applyExifOrientation(context, bitmap, rotationDegrees, isFlipped)
            }
            bitmap
        }
    }

    private fun getByGlide(): Bitmap? {
        // add signature to ignore cache for images which got modified but kept the same URI
        var options = RequestOptions()
            .format(DecodeFormat.PREFER_RGB_565)
            .signature(ObjectKey("$dateModifiedSecs-$rotationDegrees-$isFlipped-$width"))
            .override(width, height)

        val target = if (isVideo(mimeType)) {
            options = options.diskCacheStrategy(DiskCacheStrategy.RESOURCE)
            Glide.with(context)
                .asBitmap()
                .apply(options)
                .load(VideoThumbnail(context, uri))
                .submit(width, height)
        } else {
            Glide.with(context)
                .asBitmap()
                .apply(options)
                .load(uri)
                .submit(width, height)
        }

        return try {
            var bitmap = target.get()
            if (needRotationAfterGlide(mimeType)) {
                bitmap = applyExifOrientation(context, bitmap, rotationDegrees, isFlipped)
            }
            bitmap
        } finally {
            Glide.with(context).clear(target)
        }
    }

    private fun getTiff(): Bitmap? {
        // determine sample size
        var sampleSize = 1
        context.contentResolver.openFileDescriptor(uri, "r")?.use { descriptor ->
            val options = TiffBitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            TiffBitmapFactory.decodeFileDescriptor(descriptor.fd, options)
            val imageWidth = options.outWidth
            val imageHeight = options.outHeight
            if (imageHeight > height || imageWidth > width) {
                while (imageHeight / (sampleSize * 2) > height && imageWidth / (sampleSize * 2) > width) {
                    sampleSize *= 2
                }
            }
        }

        // decode
        return context.contentResolver.openFileDescriptor(uri, "r")?.use { descriptor ->
            val options = TiffBitmapFactory.Options().apply {
                inJustDecodeBounds = false
                inSampleSize = sampleSize
            }
            return TiffBitmapFactory.decodeFileDescriptor(descriptor.fd, options)
        }
    }
}