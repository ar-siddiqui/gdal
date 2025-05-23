/******************************************************************************
 *
 * Name:     typemaps_java.i
 * Project:  GDAL SWIG Interface
 * Purpose:  Typemaps for Java bindings
 * Author:   Benjamin Collins, The MITRE Corporation
 *
*/

// TODO: maintenance
//   The code below mixes uses of $result, result, and jresult.
//   Shouldn't they all be made into $result?

// TODO: we call free(), CPLFree(), and VSIFree() to free memory.
//   Can we settle on one or two instead of all three? Maybe make
//   the malloc()s into CPLMalloc()s?

%include "arrays_java.i";
%include "typemaps.i"


%fragment("SafeNewStringUTF8","header")
%{
static jstring
SafeNewStringUTF8(JNIEnv *jenv, const char* pszInput)
{
  jstring ret = 0;
  if (pszInput)
  {
      if( !CPLIsUTF8(pszInput, -1) )
      {
          CPLError(CE_Warning, CPLE_AppDefined,
                   "A non-UTF8 string has been detected. Forcing it to ASCII");
          char* pszTmp = CPLUTF8ForceToASCII(pszInput, '_');
#ifdef __cplusplus
          ret = jenv->NewStringUTF(pszTmp);
#else
          ret = (*jenv)->NewStringUTF(jenv, pszTmp);
#endif
          CPLFree(pszTmp);
      }
      else
      {
#ifdef __cplusplus
          ret = jenv->NewStringUTF(pszInput);
#else
          ret = (*jenv)->NewStringUTF(jenv, pszInput);
#endif
      }
  }
  return ret;
}
%}

// Overrides typemap defined in /usr/share/swig4.0/java.swg
%typemap(out, fragment="SafeNewStringUTF8", noblock=1) char * {
  $result = SafeNewStringUTF8(jenv, (const char *)$1);
}

%apply (int) {VSI_RETVAL};

%typemap(javabody) SWIGTYPE %{
  private long swigCPtr;
  protected boolean swigCMemOwn;

  protected $javaclassname(long cPtr, boolean cMemoryOwn) {
    if (cPtr == 0)
        throw new RuntimeException();
    swigCMemOwn = cMemoryOwn;
    swigCPtr = cPtr;
  }

  protected static long getCPtr($javaclassname obj) {
    return (obj == null) ? 0 : obj.swigCPtr;
  }
%}

/* DISOWN implementation */
%typemap(javacode) SWIGTYPE %{
  private Object parentReference;

  protected static long getCPtrAndDisown($javaclassname obj) {
    if (obj != null)
    {
        obj.swigCMemOwn= false;
        obj.parentReference = null;
    }
    return getCPtr(obj);
  }

  /* Ensure that the GC doesn't collect any parent instance set from Java */
  protected void addReference(Object reference) {
    parentReference = reference;
  }

  public boolean equals(Object obj) {
    boolean equal = false;
    if (obj instanceof $javaclassname)
      equal = ((($javaclassname)obj).swigCPtr == this.swigCPtr);
    return equal;
  }

  public int hashCode() {
     return (int)swigCPtr;
  }

%}

%typemap(javain) SWIGTYPE *DISOWN "$javaclassname.getCPtrAndDisown($javainput)"

/* JAVA TYPEMAPS */

/***************************************************
 * Typemaps for (double *val, int*hasval)
 ***************************************************/

%typemap(in) (double *val, int*hasval) ( double tmpval, int tmphasval ) {
  /* %typemap(in) (double *val, int*hasval) */
  $1 = &tmpval;
  $2 = &tmphasval;
  if($input == NULL || jenv->GetArrayLength($input) < 1) {
    SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null array or empty array");
    return $null;
  }
}

%typemap(argout) (double *val, int*hasval) {
  /* %typemap(argout) (double *val, int*hasval) */
  const jclass Double = jenv->FindClass("java/lang/Double");
  const jmethodID ctor = jenv->GetMethodID(Double, "<init>",
    "(D)V");
  if(*$2) {
    jobject dbl = jenv->NewObject(Double, ctor, tmpval$argnum);
    jenv->SetObjectArrayElement($input, (jsize)0, dbl);
  } else {
    jenv->SetObjectArrayElement($input, (jsize)0, 0);
  }
}

%typemap(jni) (double *val, int*hasval) "jobjectArray"
%typemap(jtype) (double *val, int*hasval) "Double[]"
%typemap(jstype) (double *val, int*hasval) "Double[]"
%typemap(javain) (double *val, int*hasval) "$javainput"
%typemap(javaout) (double *val, int*hasval) {
    return $jnicall;
  }


/***************************************************
 * Typemaps for (GDALColorEntry *)
 ***************************************************/

#ifdef SWIGANDROID

/* Android Version with int */

%typemap(in) (GDALColorEntry *) (GDALColorEntry tmp) {
  /* %typemap(in) (GDALColorEntry *) */
  tmp.c4 = ($input >> 24) & 0xff;
  tmp.c1 = ($input >> 16) & 0xff;
  tmp.c2 = ($input >> 8) & 0xff;
  tmp.c3 = ($input >> 0) & 0xff;
  $1 = &tmp;
}

%typemap(out) (GDALColorEntry *) {
  /* %typemap(out) (GDALColorEntry *) */
 /* Android Color is int = (alpha << 24) | (red << 16) | (green << 8) | blue */
  $result = ($1->c4 << 24) | ($1->c1 << 16) | ($1->c2 << 8) | $1->c3;
}

%typemap(jni) (GDALColorEntry *) "jint"
%typemap(jtype) (GDALColorEntry *) "int"
%typemap(jstype) (GDALColorEntry *) "int"
%typemap(javain) (GDALColorEntry *) "$javainput"
%typemap(javaout) (GDALColorEntry *) {
    return $jnicall;
  }

#else

/* J2SE Version with java.awt.Color */

%typemap(in) (GDALColorEntry *) (GDALColorEntry tmp) {
  /* %typemap(in) (GDALColorEntry *) */
  $1 = NULL;
  if ($input == NULL)
  {
      SWIG_JavaException(jenv, SWIG_ValueError, "Received a NULL pointer.");
      return $null;
  }
  float *colorptr = 0;
  const jclass Color = jenv->FindClass("java/awt/Color");
  const jmethodID colors = jenv->GetMethodID(Color, "getRGBComponents",
    "([F)[F");

  jfloatArray colorArr = jenv->NewFloatArray(4);
  colorArr = (jfloatArray)jenv->CallObjectMethod($input, colors, colorArr);

  colorptr = (float *)jenv->GetFloatArrayElements(colorArr, 0);
  tmp.c1 = (short)(colorptr[0] * 255);
  tmp.c2 = (short)(colorptr[1] * 255);
  tmp.c3 = (short)(colorptr[2] * 255);
  tmp.c4 = (short)(colorptr[3] * 255);
  /*printf( "  %d, %d, %d, %d\n",
                    tmp.c1, tmp.c2, tmp.c3, tmp.c4 );*/
  $1 = &tmp;
}

%typemap(out) (GDALColorEntry *) {
  /* %typemap(out) (GDALColorEntry *) */
  const jclass Color = jenv->FindClass("java/awt/Color");
  const jmethodID ccon = jenv->GetMethodID(Color, "<init>",
    "(IIII)V");
  $result = jenv->NewObject(Color, ccon, $1->c1, $1->c2, $1->c3, $1->c4);
}

%typemap(jni) (GDALColorEntry *) "jobject"
%typemap(jtype) (GDALColorEntry *) "java.awt.Color"
%typemap(jstype) (GDALColorEntry *) "java.awt.Color"
%typemap(javain) (GDALColorEntry *) "$javainput"
%typemap(javaout) (GDALColorEntry *) {
    return $jnicall;
  }

#endif

/***************************************************
 * Typemaps for (int nGCPs, GDAL_GCP const * pGCPs)
 ***************************************************/

%typemap(in, numinputs=1) (int nGCPs, GDAL_GCP const * pGCPs)
{
  /* %typemap(in, numinputs=1) (int nGCPs, GDAL_GCP const * pGCPs) */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = NULL;
    else
    {
        $2 = (GDAL_GCP*) malloc(sizeof(GDAL_GCP) * $1);
        int i;
        for (i=0; i<$1; i++) {
            jobject obj = (jobject)jenv->GetObjectArrayElement($input, i);
            if (obj == NULL)
            {
                free ($2 );
                SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null object in array");
                return $null;
            }
            const jclass klass = jenv->FindClass("org/gdal/gdal/GCP");
            const jmethodID getCPtr = jenv->GetStaticMethodID(klass, "getCPtr", "(Lorg/gdal/gdal/GCP;)J");
            $2[i] = *(GDAL_GCP*) jenv->CallStaticLongMethod(klass, getCPtr, obj);
        }
    }
  }
  else
  {
    $1 = 0;
    $2 = NULL;
  }
}

%typemap(freearg) (int nGCPs, GDAL_GCP const * pGCPs)
{
  /* %typemap(freearg) (int nGCPs, GDAL_GCP const * pGCPs) */
  if ($2) {
    free((void*) $2);
  }
}
%typemap(jni) (int nGCPs, GDAL_GCP const * pGCPs ) "jobjectArray"
%typemap(jtype) (int nGCPs, GDAL_GCP const * pGCPs ) "GCP[]"
%typemap(jstype) (int nGCPs, GDAL_GCP const * pGCPs ) "GCP[]"
%typemap(javain) (int nGCPs, GDAL_GCP const * pGCPs ) "$javainput"
%typemap(javaout) (int nGCPs, GDAL_GCP const * pGCPs ) {
    return $jnicall;
  }

/***************************************************
 * Typemap argout of GDAL_GCP* used in Dataset::GetGCPs( )
 ***************************************************/

%typemap(in, numinputs=1) (int *nGCPs, GDAL_GCP const **pGCPs ) (int nGCPs=0, GDAL_GCP *pGCPs=0 )
{
  /* %typemap(in, numinputs=1) (int *nGCPs, GDAL_GCP const **pGCPs ) */
  $1 = &nGCPs;
  $2 = &pGCPs;
}

%typemap(argout, fragment="SafeNewStringUTF8") (int *nGCPs, GDAL_GCP const **pGCPs )
{
  /* %typemap(argout) (int *nGCPs, GDAL_GCP const **pGCPs ) */
  const jclass GCPClass = jenv->FindClass("org/gdal/gdal/GCP");
  const jclass vectorClass = jenv->FindClass("java/util/Vector");
  const jmethodID add = jenv->GetMethodID(vectorClass, "add", "(Ljava/lang/Object;)Z");
  const jmethodID GCPcon = jenv->GetMethodID(GCPClass, "<init>",
    "(DDDDDLjava/lang/String;Ljava/lang/String;)V");

  int i;
  for (i=0; i<*$1; i++ ) {
    jstring stringInfo = SafeNewStringUTF8(jenv, (*$2)[i].pszInfo);
    jstring stringId = SafeNewStringUTF8(jenv, (*$2)[i].pszId);
    jobject GCPobj = jenv->NewObject(GCPClass, GCPcon,
                                (*$2)[i].dfGCPX,
                                (*$2)[i].dfGCPY,
                                (*$2)[i].dfGCPZ,
                                (*$2)[i].dfGCPPixel,
                                (*$2)[i].dfGCPLine,
                                stringInfo,
                                stringId);
    jenv->DeleteLocalRef(stringInfo);
    jenv->DeleteLocalRef(stringId);
    jenv->CallBooleanMethod($input, add, GCPobj);
  }
}

%typemap(jni) (int *nGCPs, GDAL_GCP const **pGCPs ) "jobject"
%typemap(jtype) (int *nGCPs, GDAL_GCP const **pGCPs ) "java.util.Vector"
%typemap(jstype) (int *nGCPs, GDAL_GCP const **pGCPs ) "java.util.Vector"
%typemap(javain) (int *nGCPs, GDAL_GCP const **pGCPs ) "$javainput"
%typemap(javaout) (int *nGCPs, GDAL_GCP const **pGCPs ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for (int nLen, unsigned char *pBuf )
 ***************************************************/

%typemap(in) (int nLen, unsigned char *pBuf )
{
  /* %typemap(in) (int nLen, unsigned char *pBuf ) */
  $1 = 0;
  $2 = NULL;
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    $2 = (unsigned char *)jenv->GetByteArrayElements($input, NULL);
  }
}

%typemap(argout) (int nLen, unsigned char *pBuf )
{
  /* %typemap(argout) (int nLen, unsigned char *pBuf ) */
}

%typemap(freearg) (int nLen, unsigned char *pBuf )
{
  /* %typemap(freearg) (int nLen, unsigned char *pBuf ) */
  /* This calls JNI_ABORT, so any modifications will not be passed back
      into the Java caller
   */
  if($2) {
    jenv->ReleaseByteArrayElements($input, (jbyte *)$2, JNI_ABORT);
  }
}

%typemap(jni) (int nLen, unsigned char *pBuf ) "jbyteArray"
%typemap(jtype) (int nLen, unsigned char *pBuf ) "byte[]"
%typemap(jstype) (int nLen, unsigned char *pBuf ) "byte[]"
%typemap(javain) (int nLen, unsigned char *pBuf ) "$javainput"
%typemap(javaout) (int nLen, unsigned char *pBuf ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (const char *pszHex, int *pnBytes)
 ***************************************************/

%typemap(in) (const char *pszHex, int *pnBytes) (int nBytes)
{
    /* %typemap(in) (const char *pszHex, int *pnBytes) */
    if ($input)
    {
        $1 = (char *)jenv->GetStringUTFChars($input, 0);
    }
    else
    {
        SWIG_JavaException(jenv, SWIG_ValueError, "Received a NULL pointer."); return $null;
    }
    $2 = &nBytes;
}

%typemap(argout) (const char *pszHex, int *pnBytes)
{
    /* %typemap(argout) (const char *pszHex, int *pnBytes) */
    if ($input)
    {
        jenv->ReleaseStringUTFChars($input, (char*)$1);
    }
    $result = jenv->NewByteArray(nBytes$argnum);
    jenv->SetByteArrayRegion($result, (jsize)0, (jsize)nBytes$argnum, (jbyte*)result);
    CPLFree(result);
}

%typemap(jni) (const char *pszHex, int *pnBytes) "jstring"
%typemap(jtype) (const char *pszHex, int *pnBytes) "String"
%typemap(jstype) (const char *pszHex, int *pnBytes) "String"
%typemap(javain) (const char *pszHex, int *pnBytes) "$javainput"
%typemap(javaout) (const char *pszHex, int *pnBytes) {
    return $jnicall;
  }


/***************************************************************
 * Typemaps for  (const char *utf8_path, vsi_l_offset *length)
 ***************************************************************/

%typemap(in) (const char *utf8_path, vsi_l_offset *length) (vsi_l_offset length)
{
    /* %typemap(in) (const char *utf8_path, vsi_l_offset *length) */
    if ($input)
    {
        $1 = (char *)jenv->GetStringUTFChars($input, 0);
    }
    else
    {
        SWIG_JavaException(jenv, SWIG_ValueError, "Received a NULL pointer."); return $null;
    }
    $2 = &length;
}

%typemap(argout) (const char *utf8_path, vsi_l_offset *length)
{
    /* %typemap(argout) (const char *utf8_path, vsi_l_offset *length) */
    if ($input)
    {
        jenv->ReleaseStringUTFChars($input, (char*)$1);
    }
    $result = jenv->NewByteArray((jsize)length$argnum);
    jenv->SetByteArrayRegion($result, (jsize)0, (jsize)length$argnum, (jbyte*)result);
    // Do not free result, as it is owned by the /vsimem/ file
}

%typemap(jni) (const char *utf8_path, vsi_l_offset *length) "jstring"
%typemap(jtype) (const char *utf8_path, vsi_l_offset *length) "String"
%typemap(jstype) (const char *utf8_path, vsi_l_offset *length) "String"
%typemap(javain) (const char *utf8_path, vsi_l_offset *length) "$javainput"
%typemap(javaout) (const char *utf8_path, vsi_l_offset *length) {
    return $jnicall;
  }


/***************************************************
 * Typemaps for  (GByte* outBytes )
 ***************************************************/

%typemap(out) (GByte* outBytes )
{
  /* %typemap(out) (GByte* outBytes ) */
}

%typemap(jni) (GByte* outBytes ) "jbyteArray"
%typemap(jtype) (GByte* outBytes ) "byte[]"
%typemap(jstype) (GByte* outBytes ) "byte[]"
%typemap(javain) (GByte* outBytes ) "$javainput"
%typemap(javaout) (GByte* outBytes ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (const char* stringWithDefaultValue)
 ***************************************************/

%typemap(in) (const char* stringWithDefaultValue)
{
  /* %typemap(in) (const char* stringWithDefaultValue) */
  if ($input)
  {
    $1 = (char *)jenv->GetStringUTFChars($input, 0);
  }
}

%typemap(freearg) (const char* stringWithDefaultValue)
{
  /* %typemap(freearg) (const char* stringWithDefaultValue) */
  if ($input)
  {
    jenv->ReleaseStringUTFChars($input, (char*)$1);
  }
}

%typemap(jni) (const char* stringWithDefaultValue) "jstring"
%typemap(jtype) (const char* stringWithDefaultValue) "String"
%typemap(jstype) (const char* stringWithDefaultValue) "String"
%typemap(javain) (const char* stringWithDefaultValue) "$javainput"
%typemap(javaout) (const char* stringWithDefaultValue) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (tostring argin)
 ***************************************************/

%typemap(in) (tostring argin)
{
  /* %typemap(in) (tostring argin) */
  if ($input)
    $1 = (char *)jenv->GetStringUTFChars($input, 0);
}

%typemap(freearg) (tostring argin)
{
  /* %typemap(freearg) (tostring argin) */
  if ($input)
    jenv->ReleaseStringUTFChars($input, (char*)$1);
}

%typemap(jni) (tostring argin) "jstring"
%typemap(jtype) (tostring argin) "String"
%typemap(jstype) (tostring argin) "String"
%typemap(javain) (tostring argin) "$javainput"
%typemap(javaout) (tostring argin) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (retStringAndCPLFree*)
 ***************************************************/

%typemap(out, fragment="SafeNewStringUTF8") (retStringAndCPLFree*)
{
    /* %typemap(out) (retStringAndCPLFree*) */
    if(result)
    {
        $result = SafeNewStringUTF8(jenv, (const char *)result);
        CPLFree(result);
    }
}

%typemap(jni) (retStringAndCPLFree*) "jstring"
%typemap(jtype) (retStringAndCPLFree*) "String"
%typemap(jstype) (retStringAndCPLFree*) "String"
%typemap(javain) (retStringAndCPLFree*) "$javainput"
%typemap(javaout) (retStringAndCPLFree*) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for (StringAsByteArray*)
 ***************************************************/

%typemap(out) (StringAsByteArray*)
{
    /* %typemap(out) (StringAsByteArray*) */
    if(result)
    {
        const size_t nLen = strlen((const char*)result);
        jbyteArray byteArray = jenv->NewByteArray(nLen);
        jenv->SetByteArrayRegion(byteArray, (jsize)0, (jsize)nLen, (jbyte*)result);
        $result = byteArray;
    }
}

%typemap(jni) (StringAsByteArray*) "jbyteArray"
%typemap(jtype) (StringAsByteArray*) "byte[]"
%typemap(jstype) (StringAsByteArray*) "byte[]"
%typemap(javain) (StringAsByteArray*) "$javainput"
%typemap(javaout) (StringAsByteArray*) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (char **ignorechange)
 ***************************************************/

%typemap(in) (char **ignorechange) (char* ori_val, char *val)
{
  /* %typemap(in) (char **ignorechange) */
  ori_val = val = (char *)jenv->GetStringUTFChars($input, 0);
  $1 = &val;
}

%typemap(freearg) (char **ignorechange)
{
  /* %typemap(freearg) (char **ignorechange) */
  jenv->ReleaseStringUTFChars($input, ori_val$argnum);
}

%typemap(jni) (char **ignorechange) "jstring"
%typemap(jtype) (char **ignorechange) "String"
%typemap(jstype) (char **ignorechange) "String"
%typemap(javain) (char **ignorechange) "$javainput"
%typemap(javaout) (char **ignorechange) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (int *nLen, char **pBuf)
 ***************************************************/

%typemap(in,numinputs=0) (int *nLen, char **pBuf ) ( int nLen, char *pBuf )
{
  /* %typemap(in,numinputs=0) (int *nLen, char **pBuf ) */
  $1 = &nLen;
  $2 = &pBuf;
}

%typemap(argout) (int *nLen, char **pBuf )
{
  /* %typemap(argout) (int *nLen, char **pBuf ) */
  jbyteArray byteArray = jenv->NewByteArray(nLen$argnum);
  jenv->SetByteArrayRegion(byteArray, (jsize)0, (jsize)nLen$argnum, (jbyte*)pBuf$argnum);
  $result = byteArray;
}

%typemap(freearg) (int *nLen, char **pBuf )
{
  /* %typemap(freearg) (int *nLen, char **pBuf ) */
  if( nLen$argnum ) {
    VSIFree(pBuf$argnum);
  }
}

%typemap(jni) (int *nLen, char **pBuf ) "jbyteArray"
%typemap(jtype) (int *nLen, char **pBuf ) "byte[]"
%typemap(jstype) (int *nLen, char **pBuf ) "byte[]"
%typemap(javain) (int *nLen, char **pBuf ) "$javainput"
%typemap(javaout) (int *nLen, char **pBuf ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for  (size_t *nLen, char **pBuf)
 ***************************************************/

%typemap(in,numinputs=0) (size_t *nLen, char **pBuf ) ( size_t nLen, char *pBuf )
{
  /* %typemap(in,numinputs=0) (size_t *nLen, char **pBuf ) */
  $1 = &nLen;
  $2 = &pBuf;
}

%typemap(argout) (size_t *nLen, char **pBuf )
{
  /* %typemap(argout) (size_t *nLen, char **pBuf ) */
  jbyteArray byteArray = jenv->NewByteArray(nLen$argnum);
  jenv->SetByteArrayRegion(byteArray, (jsize)0, (jsize)nLen$argnum, (jbyte*)pBuf$argnum);
  $result = byteArray;
}

%typemap(freearg) (size_t *nLen, char **pBuf )
{
  /* %typemap(freearg) (size_t *nLen, char **pBuf ) */
  if( nLen$argnum ) {
    VSIFree(pBuf$argnum);
  }
}

%typemap(jni) (size_t *nLen, char **pBuf ) "jbyteArray"
%typemap(jtype) (size_t *nLen, char **pBuf ) "byte[]"
%typemap(jstype) (size_t *nLen, char **pBuf ) "byte[]"
%typemap(javain) (size_t *nLen, char **pBuf ) "$javainput"
%typemap(javaout) (size_t *nLen, char **pBuf ) {
    return $jnicall;
  }


%import "ogr_error_map.i"

%typemap(out,fragment="OGRErrMessages") OGRErr
{
  /* %typemap(out,fragment="OGRErrMessages") OGRErr */
  if (result != 0 && bUseExceptions) {
    SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException,
      OGRErrMessages(result));
    return $null;
  }
  $result = (jint)result;
}

%typemap(ret) OGRErr
{
  /* %typemap(ret) OGRErr */
}

/* GDAL Typemaps */

%typemap(out) IF_ERR_RETURN_NONE
{
  /* %typemap(out) IF_ERR_RETURN_NONE */
  $result = 0;
}

%typemap(ret) IF_ERR_RETURN_NONE
{
  /* %typemap(ret) IF_ERR_RETURN_NONE */
}

%typemap(out) IF_FALSE_RETURN_NONE
{
  /* %typemap(out) IF_FALSE_RETURN_NONE */
  $result = 0;
}

%typemap(ret) IF_FALSE_RETURN_NONE
{
  /* %typemap(ret) IF_FALSE_RETURN_NONE */
}

/***************************************************
 *
 *  Java typemaps for (int nList, int* pList)
 *
 ***************************************************/

%typemap(in) (int nList, int* pList)
{
  /* %typemap(in) (int nList, int* pList) */
  /* check if is List */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = NULL;
    else
       $2 = (int *)jenv->GetIntArrayElements($input, NULL);
  }
  else
  {
    $1 = 0;
    $2 = NULL;
  }
}

%typemap(argout) (int nList, int* pList)
{
  /* %typemap(argout) (int nList, int* pList) */
}

%typemap(freearg) (int nList, int* pList)
{
  /* %typemap(freearg) (int nList, int* pList) */
  if ($2) {
    jenv->ReleaseIntArrayElements($input, (jint*)$2, JNI_ABORT);
  }
}

%typemap(jni) (int nList, int* pList) "jintArray"
%typemap(jtype) (int nList, int* pList) "int[]"
%typemap(jstype) (int nList, int* pList) "int[]"
%typemap(javain) (int nLen, int* pList ) "$javainput"
%typemap(javaout) (int nLen, int* pList ) {
    return $jnicall;
  }


/***************************************************
 *
 *  Java typemaps for (int nList, int* pListOut)
 *
 ***************************************************/
%typemap(in) (int nList, int* pListOut)
{
  /* %typemap(in) (int nList, int* pListOut) */
  /* check if is List */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    $2 = (int*) malloc($1 * sizeof(int));
  }
  else
  {
    $1 = 0;
    $2 = NULL;
  }
}

%typemap(argout) (int nList, int* pListOut)
{
  /* %typemap(argout) (int nList, int* pListOut) */
}

%typemap(freearg) (int nList, int* pListOut)
{
  /* %typemap(freearg) (int nList, int* pListOut) */
  if ($2) {
    jenv->SetIntArrayRegion($input, 0, $1, (jint*)$2);
    free((void*) $2);
  }
}

%typemap(jni) (int nList, int* pListOut) "jintArray"
%typemap(jtype) (int nList, int* pListOut) "int[]"
%typemap(jstype) (int nList, int* pListOut) "int[]"
%typemap(javain) (int nLen, int* pListOut ) "$javainput"
%typemap(javaout) (int nLen, int* pListOut ) {
    return $jnicall;
  }


/***************************************************
 *
 *  Java typemaps for (int* pnList, int** ppListOut)
 *
 ***************************************************/
%typemap(in) (int* pnList, int** ppListOut) (int nLen = 0, int* pBuf = NULL)
{
  /* %typemap(in) (int* pnList, int** ppListOut) */
  $1 = &nLen;
  $2 = &pBuf;
}

%typemap(argout) (int* pnList, int** ppListOut)
{
  /* %typemap(argout) (int* pnList, int** ppListOut) */
  if($input && jenv->GetArrayLength($input) >= 1)
  {
    jintArray intArray = jenv->NewIntArray(nLen$argnum);
    jenv->SetIntArrayRegion(intArray, (jsize)0, (jsize)nLen$argnum, (jint*)pBuf$argnum);
    jenv->SetObjectArrayElement($input,0,intArray);
    jenv->DeleteLocalRef(intArray);
  }
  CPLFree(pBuf$argnum);
}

%typemap(freearg) (int* pnList, int** ppListOut)
{
  /* %typemap(freearg) (int* pnList, int** ppListOut) */
}

%typemap(jni) (int* pnList, int** ppListOut) "jobjectArray"
%typemap(jtype) (int* pnList, int** ppListOut) "int[][]"
%typemap(jstype) (int* pnList, int** ppListOut) "int[][]"
%typemap(javain) (int* pnList, int** ppListOut) "$javainput"
%typemap(javaout) (int* pnList, int** ppListOut) {
    return $jnicall;
  }

/***************************************************
 *
 *  Java typemaps for (int id, int *nLen, const int **pList)
 *
 ***************************************************/
%typemap(in) (int id, int *nLen, const int **pList) (int nLen, int* pList)
{
  /* %typemap(in) (int id, int *nLen, const int **pList) */
  $1 = $input;
  $2 = &nLen;
  $3 = &pList;
}

%typemap(argout) (int id, int *nLen, const int **pList)
{
  /* %typemap(argout) (int id, int *nLen, const int **pList) */
  jintArray intArray = jenv->NewIntArray(nLen$argnum);
  jenv->SetIntArrayRegion(intArray, (jsize)0, (jsize)nLen$argnum, (jint*)pList$argnum);
  $result = intArray;
}

%typemap(freearg) (int id, int *nLen, const int **pList)
{
  /* %typemap(freearg) (int id, int *nLen, const int **pList) */
}

%typemap(jni) (int id, int *nLen, const int **pList) "jint"
%typemap(jtype) (int id, int *nLen, const int **pList) "int"
%typemap(jstype) (int id, int *nLen, const int **pList) "int"
%typemap(javain) (int id, int *nLen, const int **pList) "$javainput"
%typemap(javaout) (int id, int *nLen, const int **pList) {
    return $jnicall;
  }

%typemap(out) (retIntArray)
{
  /* %typemap(out) (retIntArray) */
}

%typemap(jni) (retIntArray) "jintArray"
%typemap(jtype) (retIntArray) "int[]"
%typemap(jstype) (retIntArray) "int[]"
%typemap(javain) (retIntArray) "$javainput"
%typemap(javaout) (retIntArray) {
    return $jnicall;
  }

/***************************************************
 *
 *  Java typemaps for (int id, int *nLen, const double **pList)
 *
 ***************************************************/
%typemap(in) (int id, int *nLen, const double **pList) (int nLen, double* pList)
{
  /* %typemap(in) (int id, int *nLen, const double **pList) */
  $1 = $input;
  $2 = &nLen;
  $3 = &pList;
}

%typemap(argout) (int id, int *nLen, const double **pList)
{
  /* %typemap(argout) (int id, int *nLen, const double **pList) */
  jdoubleArray doubleArray = jenv->NewDoubleArray(nLen$argnum);
  jenv->SetDoubleArrayRegion(doubleArray, (jsize)0, (jsize)nLen$argnum, pList$argnum);
  $result = doubleArray;
}

%typemap(freearg) (int id, int *nLen, const double **pList)
{
  /* %typemap(freearg) (int id, int *nLen, const double **pList) */
}

%typemap(jni) (int id, int *nLen, const double **pList) "jint"
%typemap(jtype) (int id, int *nLen, const double **pList) "int"
%typemap(jstype) (int id, int *nLen, const double **pList) "int"
%typemap(javain) (int id, int *nLen, const double **pList) "$javainput"
%typemap(javaout) (int id, int *nLen, const double **pList) {
    return $jnicall;
  }

%typemap(out) (retDoubleArray)
{
  /* %typemap(out) (retDoubleArray) */
}

%typemap(jni) (retDoubleArray) "jdoubleArray"
%typemap(jtype) (retDoubleArray) "double[]"
%typemap(jstype) (retDoubleArray) "double[]"
%typemap(javain) (retDoubleArray) "$javainput"
%typemap(javaout) (retDoubleArray) {
    return $jnicall;
  }

/***************************************************
 *
 *  Java typemaps for (int nList, double* pList)
 *
 ***************************************************/

%typemap(in) (int nList, double* pList)
{
  /* %typemap(in) (int nList, double* pList) */
  /* check if is List */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = NULL;
    else
       $2 = (double *)jenv->GetDoubleArrayElements($input, NULL);
  }
  else
  {
    $1 = 0;
    $2 = NULL;
  }
}

%typemap(argout) (int nList, double* pList)
{
  /* %typemap(argout) (int nList, double* pList) */
}

%typemap(freearg) (int nList, double* pList)
{
  /* %typemap(freearg) (int nList, double* pList) */
  if ($2) {
    jenv->ReleaseDoubleArrayElements($input, $2, JNI_ABORT);
  }
}

%typemap(jni) (int nList, double* pList) "jdoubleArray"
%typemap(jtype) (int nList, double* pList) "double[]"
%typemap(jstype) (int nList, double* pList) "double[]"
%typemap(javain) (int nLen, double *pList ) "$javainput"
%typemap(javaout) (int nLen, double *pList ) {
    return $jnicall;
  }

/***************************************************
 *
 *  Java typemaps for (int object_list_count, GDALRasterBandShadow **poObjects)
 *
 ***************************************************/

%typemap(in) (int object_list_count, GDALRasterBandShadow **poObjects)
{
  /* %typemap(in) (int object_list_count, GDALRasterBandShadow **poObjects) */
  /* check if is List */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = NULL;
    else
    {
        $2 = (GDALRasterBandShadow**) malloc(sizeof(GDALRasterBandShadow*) * $1);
        int i;
        for (i=0; i<$1; i++) {
            jobject obj = (jobject)jenv->GetObjectArrayElement($input, i);
            if (obj == NULL)
            {
                free ($2 );
                SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null object in array");
                return $null;
            }
            const jclass klass = jenv->FindClass("org/gdal/gdal/Band");
            const jmethodID getCPtr = jenv->GetStaticMethodID(klass, "getCPtr", "(Lorg/gdal/gdal/Band;)J");
            $2[i] = (GDALRasterBandShadow*) jenv->CallStaticLongMethod(klass, getCPtr, obj);
        }
    }
  }
  else
  {
    $1 = 0;
    $2 = NULL;
  }
}

%typemap(argout) (int object_list_count, GDALRasterBandShadow **poObjects)
{
  /* %typemap(argout) (int object_list_count, GDALRasterBandShadow **poObjects) */
}

%typemap(freearg) (int object_list_count, GDALRasterBandShadow **poObjects)
{
  /* %typemap(freearg) (int object_list_count, GDALRasterBandShadow **poObjects) */
  if ($2) {
    free((void*) $2);
  }
}

%typemap(jni) (int object_list_count, GDALRasterBandShadow **poObjects) "jobjectArray"
%typemap(jtype) (int object_list_count, GDALRasterBandShadow **poObjects) "Band[]"
%typemap(jstype) (int object_list_count, GDALRasterBandShadow **poObjects) "Band[]"
%typemap(javain) (int object_list_count, GDALRasterBandShadow **poObjects) "$javainput"
%typemap(javaout) (int object_list_count, GDALRasterBandShadow **poObjects) {
    return $jnicall;
  }

/***************************************************
 *
 *  Java typemaps for (int object_list_count, GDALDatasetShadow **poObjects)
 *
 ***************************************************/

%typemap(in) (int object_list_count, GDALDatasetShadow **poObjects)
{
  /* %typemap(in) (int object_list_count, GDALDatasetShadow **poObjects) */
  /* check if is List */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = NULL;
    else
    {
        $2 = (GDALDatasetShadow**) malloc(sizeof(GDALDatasetShadow*) * $1);
        int i;
        for (i=0; i<$1; i++) {
            jobject obj = (jobject)jenv->GetObjectArrayElement($input, i);
            if (obj == NULL)
            {
                free ($2 );
                SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null object in array");
                return $null;
            }
            const jclass klass = jenv->FindClass("org/gdal/gdal/Dataset");
            const jmethodID getCPtr = jenv->GetStaticMethodID(klass, "getCPtr", "(Lorg/gdal/gdal/Dataset;)J");
            $2[i] = (GDALDatasetShadow*) jenv->CallStaticLongMethod(klass, getCPtr, obj);
        }
    }
  }
  else
  {
    $1 = 0;
    $2 = NULL;
  }
}

%typemap(argout) (int object_list_count, GDALDatasetShadow **poObjects)
{
  /* %typemap(argout) (int object_list_count, GDALDatasetShadow **poObjects) */
}

%typemap(freearg) (int object_list_count, GDALDatasetShadow **poObjects)
{
  /* %typemap(freearg) (int object_list_count, GDALDatasetShadow **poObjects) */
  if ($2) {
    free((void*) $2);
  }
}

%typemap(jni) (int object_list_count, GDALDatasetShadow **poObjects) "jobjectArray"
%typemap(jtype) (int object_list_count, GDALDatasetShadow **poObjects) "Dataset[]"
%typemap(jstype) (int object_list_count, GDALDatasetShadow **poObjects) "Dataset[]"
%typemap(javain) (int object_list_count, GDALDatasetShadow **poObjects) "$javainput"
%typemap(javaout) (int object_list_count, GDALDatasetShadow **poObjects) {
    return $jnicall;
  }

/***************************************************
 * Typemaps converts the Hashtable to a char array *
 ***************************************************/

%typemap(in) char **dict
{
  /* %typemap(in) char **dict */
  /* Convert the Hashtable to a char array */
  $1 = NULL;
  if($input != 0) {
    const jclass hashtable = jenv->FindClass("java/util/Hashtable");
    const jclass enumeration = jenv->FindClass("java/util/Enumeration");
    const jclass stringClass = jenv->FindClass("java/lang/String");
    const jmethodID get = jenv->GetMethodID(hashtable, "get",
      "(Ljava/lang/Object;)Ljava/lang/Object;");
    const jmethodID keys = jenv->GetMethodID(hashtable, "keys",
      "()Ljava/util/Enumeration;");
    const jmethodID hasMoreElements = jenv->GetMethodID(enumeration,
      "hasMoreElements", "()Z");
    const jmethodID nextElement = jenv->GetMethodID(enumeration,
      "nextElement", "()Ljava/lang/Object;");
    for (jobject keyset = jenv->CallObjectMethod($input, keys);
          jenv->CallBooleanMethod(keyset, hasMoreElements) == JNI_TRUE;) {
      jstring key = (jstring)jenv->CallObjectMethod(keyset, nextElement);
      if (key == NULL || !jenv->IsInstanceOf(key, stringClass))
      {
          CSLDestroy($1);
          SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "a key in the hashtable is not a string");
          return $null;
      }
      jstring value = (jstring)jenv->CallObjectMethod($input, get, key);
      if (value != NULL && !jenv->IsInstanceOf(value, stringClass))
      {
          CSLDestroy($1);
          SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "a value in the hashtable is not a string");
          return $null;
      }
      const char *keyptr = jenv->GetStringUTFChars(key, 0);
      const char *valptr = jenv->GetStringUTFChars(value, 0);
      $1 = CSLAddNameValue($1, keyptr, valptr);
      jenv->ReleaseStringUTFChars(key, keyptr);
      jenv->ReleaseStringUTFChars(value, valptr);
    }
  }
}

%fragment("GetCSLStringAsHashTable","header", fragment="SafeNewStringUTF8")
%{
/* Convert a char array to a Hashtable */
static jobject
GetCSLStringAsHashTable(JNIEnv *jenv, char **stringarray, bool bFreeCSL ) {
  const jclass hashtable = jenv->FindClass("java/util/Hashtable");
  const jmethodID constructor = jenv->GetMethodID(hashtable, "<init>", "()V");
  const jmethodID put = jenv->GetMethodID(hashtable, "put",
    "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  jobject jHashtable = jenv->NewObject(hashtable, constructor);
  if ( stringarray != NULL ) {
    while (*stringarray != NULL ) {
      char const *valptr;
      char *keyptr;
      const char* pszSep = strchr( *stringarray, '=' );
      if ( pszSep != NULL) {
        keyptr = CPLStrdup(*stringarray);
        keyptr[pszSep - *stringarray] = '\0';
        valptr = pszSep + 1;
        jstring name = SafeNewStringUTF8(jenv, keyptr);
        jstring value = SafeNewStringUTF8(jenv, valptr);
        jenv->CallObjectMethod(jHashtable, put, name, value);
        jenv->DeleteLocalRef(name);
        jenv->DeleteLocalRef(value);
        CPLFree(keyptr);
      }
      stringarray++;
    }
  }
  if( bFreeCSL )
    CSLDestroy(stringarray);
  return jHashtable;
}
%}

%typemap(out,fragment="GetCSLStringAsHashTable") char **dict
{
  /* %typemap(out) char **dict */
  $result = GetCSLStringAsHashTable(jenv, $1, false);
}

%typemap(freearg) char **dict
{
  /* %typemap(freearg) char **dict */
  CSLDestroy( $1 );
}

%typemap(jni) (char **dict) "jobject"
%typemap(jtype) (char **dict) "java.util.Hashtable"
%typemap(jstype) (char **dict) "java.util.Hashtable"
%typemap(javain) (char **dict) "$javainput"
%typemap(javaout) (char **dict) {
    return $jnicall;
  }


/*
 * Typemap char ** -> dict and CSLDestroy()
 */
%typemap(out,fragment="GetCSLStringAsHashTable") char **dictAndCSLDestroy
{
  /* %typemap(out) char **dictAndCSLDestroy */
  $result = GetCSLStringAsHashTable(jenv, $1, true);
}
%typemap(jni) (char **dictAndCSLDestroy) "jobject"
%typemap(jtype) (char **dictAndCSLDestroy) "java.util.Hashtable"
%typemap(jstype) (char **dictAndCSLDestroy) "java.util.Hashtable"
%typemap(javaout) (char **dictAndCSLDestroy) {
    return $jnicall;
  }

/***************************************************
 * Typemaps maps char** arguments from a Vector
 ***************************************************/

%typemap(in) char **options
{
  /* %typemap(in) char **options */
  $1 = NULL;
  if($input != 0) {
    const jclass vector = jenv->FindClass("java/util/Vector");
    const jclass enumeration = jenv->FindClass("java/util/Enumeration");
    const jclass stringClass = jenv->FindClass("java/lang/String");
    const jmethodID elements = jenv->GetMethodID(vector, "elements",
      "()Ljava/util/Enumeration;");
    const jmethodID hasMoreElements = jenv->GetMethodID(enumeration,
      "hasMoreElements", "()Z");
    const jmethodID getNextElement = jenv->GetMethodID(enumeration,
      "nextElement", "()Ljava/lang/Object;");
    if(vector == NULL || enumeration == NULL || elements == NULL ||
        hasMoreElements == NULL || getNextElement == NULL) {
          fprintf(stderr, "Could not load (options **) jni types.\n");
          return $null;
        }
    for (jobject keys = jenv->CallObjectMethod($input, elements);
          jenv->CallBooleanMethod(keys, hasMoreElements) == JNI_TRUE;) {
      jstring value = (jstring)jenv->CallObjectMethod(keys, getNextElement);
      if (value == NULL || !jenv->IsInstanceOf(value, stringClass))
      {
          CSLDestroy($1);
          SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "an element in the vector is not a string");
          return $null;
      }
      const char *valptr = jenv->GetStringUTFChars(value, 0);
      $1 = CSLAddString($1,  valptr);
      jenv->ReleaseStringUTFChars(value, valptr);
    }
  }
}

%typemap(freearg) char **options
{
  /* %typemap(freearg) char **options */
  CSLDestroy( $1 );
}

%typemap(out, fragment="SafeNewStringUTF8") char **options
{
  /* %typemap(out) char **options */
  char **stringarray = $1;
  const jclass vector = jenv->FindClass("java/util/Vector");
  const jmethodID constructor = jenv->GetMethodID(vector, "<init>", "()V");
  const jmethodID add = jenv->GetMethodID(vector, "add", "(Ljava/lang/Object;)Z");

  $result = jenv->NewObject(vector, constructor);
  if ( stringarray != NULL ) {
    while(*stringarray != NULL) {
      jstring value = SafeNewStringUTF8(jenv, *stringarray);
      jenv->CallBooleanMethod($result, add, value);
      jenv->DeleteLocalRef(value);
      stringarray++;
    }
  }
}

%typemap(jni) (char **options) "jobject"
%typemap(jtype) (char **options) "java.util.Vector"
%typemap(jstype) (char **options) "java.util.Vector"
%typemap(javain) (char **options) "$javainput"
%typemap(javaout) (char **options) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for retAsStringArrayNoFree
 ***************************************************/

%typemap(out,fragment="SafeNewStringUTF8") char **retAsStringArrayNoFree
{
  /* %typemap(out) char **retAsStringArrayNoFree */
  char **stringarray = result;
  int i;
  int len=CSLCount(result);
  jstring temp_string;
  const jclass clazz = jenv->FindClass("java/lang/String");

  $result = jenv->NewObjectArray(len, clazz, NULL);
  /* exception checking omitted */

  for (i=0; i<len; i++) {
      temp_string = SafeNewStringUTF8(jenv, *stringarray++);
      jenv->SetObjectArrayElement(jresult, i, temp_string);
      jenv->DeleteLocalRef(temp_string);
  }
}

%typemap(jni) (char **retAsStringArrayNoFree) "jobjectArray"
%typemap(jtype) (char **retAsStringArrayNoFree) "String[]"
%typemap(jstype) (char **retAsStringArrayNoFree) "String[]"
%typemap(javain) (char **retAsStringArrayNoFree) "$javainput"
%typemap(javaout) (char **retAsStringArrayNoFree) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for retAsStringArrayNoFree
 ***************************************************/

%typemap(out, fragment="SafeNewStringUTF8") char **retAsStringArrayAndFree
{
  /* %typemap(out) char **retAsStringArrayAndFree */
  char **stringarray = result;
  int i;
  int len=CSLCount(result);
  jstring temp_string;
  const jclass clazz = jenv->FindClass("java/lang/String");

  $result = jenv->NewObjectArray(len, clazz, NULL);
  /* exception checking omitted */

  for (i=0; i<len; i++) {
      temp_string = SafeNewStringUTF8(jenv, *stringarray++);
      jenv->SetObjectArrayElement(jresult, i, temp_string);
      jenv->DeleteLocalRef(temp_string);
  }

  CSLDestroy(result);
}

%typemap(jni) (char **retAsStringArrayAndFree) "jobjectArray"
%typemap(jtype) (char **retAsStringArrayAndFree) "String[]"
%typemap(jstype) (char **retAsStringArrayAndFree) "String[]"
%typemap(javain) (char **retAsStringArrayAndFree) "$javainput"
%typemap(javaout) (char **retAsStringArrayAndFree) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for char **OUTPUT
 ***************************************************/

%typemap(in) char **OUTPUT (char* ret)
{
    /* %typemap(in) char **OUTPUT */
    if (!$input) {
      SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "array null");
      return $null;
    }
    if (jenv->GetArrayLength($input) == 0) {
      SWIG_JavaThrowException(jenv, SWIG_JavaIndexOutOfBoundsException, "Array must contain at least 1 element");
      return $null;
    }
    $1 = &ret;
}

%typemap(argout, fragment="SafeNewStringUTF8") char **OUTPUT
{
  /* %typemap(argout) char **OUTPUT */
  jstring temp_string = SafeNewStringUTF8(jenv, ret$argnum);
  jenv->SetObjectArrayElement($input, 0, temp_string);
  jenv->DeleteLocalRef(temp_string);
}

%typemap(jni) (char **OUTPUT) "jobjectArray"
%typemap(jtype) (char **OUTPUT) "String[]"
%typemap(jstype) (char **OUTPUT) "String[]"
%typemap(javain) (char **OUTPUT) "$javainput"
%typemap(javaout) (char **OUTPUT) {
    return $jnicall;
  }


/***************************************************
 * Typemaps for char** CSL
 ***************************************************/

/* Almost same as %typemap(out) char **options */
/* but we CSLDestroy the char** pointer at the end */

%typemap(out, fragment="SafeNewStringUTF8") char **CSL
{
  /* %typemap(out) char **CSL */
  char **stringarray = $1;
  const jclass vector = jenv->FindClass("java/util/Vector");
  const jmethodID constructor = jenv->GetMethodID(vector, "<init>", "()V");
  const jmethodID add = jenv->GetMethodID(vector, "add", "(Ljava/lang/Object;)Z");

  $result = jenv->NewObject(vector, constructor);
  if ( stringarray != NULL ) {
    while(*stringarray != NULL) {
      jstring value = SafeNewStringUTF8(jenv, *stringarray);
      jenv->CallBooleanMethod($result, add, value);
      jenv->DeleteLocalRef(value);
      stringarray++;
    }
  }
  CSLDestroy($1);
}

%typemap(jni) (char **CSL) "jobject"
%typemap(jtype) (char **CSL) "java.util.Vector"
%typemap(jstype) (char **CSL) "java.util.Vector"
%typemap(javain) (char **CSL) "$javainput"
%typemap(javaout) (char **CSL) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for char **argout.
 ***************************************************/

%typemap(in) (char **argout) ( char *argout=0 )
{
  /* %typemap(in) (char **argout) */
  $1 = &argout;
}

%typemap(argout, fragment="SafeNewStringUTF8") (char **argout)
{
  /* %typemap(argout) (char **argout) */
  jstring temp_string;

  if($input != NULL && (int)jenv->GetArrayLength($input) >= 1) {
    temp_string = SafeNewStringUTF8(jenv, argout$argnum);
    jenv->SetObjectArrayElement($input, 0, temp_string);
    jenv->DeleteLocalRef(temp_string);
  }
}

%typemap(freearg) (char **argout)
{
  /* %typemap(freearg) (char **argout) */
  if($1) {
    CPLFree((void *) argout$argnum);
  }
}

%typemap(jni) (char **argout) "jobjectArray"
%typemap(jtype) (char **argout) "String[]"
%typemap(jstype) (char **argout) "String[]"
%typemap(javain) (char **argout) "$javainput"
%typemap(javaout) (char **argout) {
    return $jnicall;
  }


/***************************************************
 * Typemaps for double *argout[ANY]
 ***************************************************/

%typemap(in) (double *argout[ANY]) (double *argout)
{
  /* %typemap(in) (double *argout[ANY]) */
  if($input == NULL || jenv->GetArrayLength($input) != $dim0) {
      char errorMsg[128];
      snprintf(errorMsg, sizeof(errorMsg), "array of size %d expected", $dim0);
      SWIG_JavaThrowException(jenv, SWIG_JavaIndexOutOfBoundsException, errorMsg);
      return $null;
  }
  $1 = &argout;
}

%typemap(argout) (double *argout[ANY])
{
  /* %typemap(argout) (double *argout[ANY]) */
  jenv->SetDoubleArrayRegion($input, (jsize)0, (jsize)$dim0, *$1);
}

%typemap(freearg) (double *argout[ANY])
{
  /* %typemap(freearg) (double *argout[ANY]) */
  CPLFree(*$1);
}

%typemap(jni) (double *argout[ANY]) "jdoubleArray"
%typemap(jtype) (double *argout[ANY]) "double[]"
%typemap(jstype) (double *argout[ANY]) "double[]"
%typemap(javain) (double *argout[ANY]) "$javainput"
%typemap(javaout) (double *argout[ANY]) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for double argin[ANY]
 ***************************************************/

%typemap(in) (double argin[ANY])
{
  /* %typemap(in) (double argin[ANY]) */
  if($input == NULL || jenv->GetArrayLength($input) != $dim0) {
      char errorMsg[128];
      snprintf(errorMsg, sizeof(errorMsg), "array of size %d expected", $dim0);
      SWIG_JavaThrowException(jenv, SWIG_JavaIndexOutOfBoundsException, errorMsg);
      return $null;
  }
  $1 = (double *)jenv->GetDoubleArrayElements($input, NULL);
}

%typemap(argout) (double argin[ANY])
{
  /* %typemap(argout) (double argin[ANY]) */
}

%typemap(freearg) (double argin[ANY])
{
  /* %typemap(freearg) (double argin[ANY]) */
  if($1) {
    jenv->ReleaseDoubleArrayElements($input, (jdouble *)$1, JNI_ABORT);
  }
}

%typemap(jni) (double argin[ANY]) "jdoubleArray"
%typemap(jtype) (double argin[ANY]) "double[]"
%typemap(jstype) (double argin[ANY]) "double[]"
%typemap(javain) (double argin[ANY]) "$javainput"
%typemap(javaout) (double argin[ANY]) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for double argout[ANY]
 ***************************************************/

%typemap(in) (double argout[ANY])
{
  /* %typemap(in) (double argout[ANY]) */
  if($input == NULL || jenv->GetArrayLength($input) != $dim0) {
      char errorMsg[128];
      snprintf(errorMsg, sizeof(errorMsg), "array of size %d expected", $dim0);
      SWIG_JavaThrowException(jenv, SWIG_JavaIndexOutOfBoundsException, errorMsg);
      return $null;
  }
  $1 = (double *)jenv->GetDoubleArrayElements($input, NULL);
}

%typemap(argout) (double argout[ANY])
{
  /* %typemap(argout) (double argout[ANY]) */
}

%typemap(freearg) (double argout[ANY])
{
  /* %typemap(freearg) (double argout[ANY]) */
  jenv->ReleaseDoubleArrayElements($input, (jdouble *)$1, 0);
}

%typemap(jni) (double argout[ANY]) "jdoubleArray"
%typemap(jtype) (double argout[ANY]) "double[]"
%typemap(jstype) (double argout[ANY]) "double[]"
%typemap(javain) (double argout[ANY]) "$javainput"
%typemap(javaout) (double argout[ANY]) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for char **
 ***************************************************/

/* This tells SWIG to treat char ** as a special case when used as a parameter
   in a function call */

%typemap(in) char ** (jint size) {
    /* %typemap(in) char ** */
    int i = 0;
    size = jenv->GetArrayLength($input);
    $1 = (char **) malloc((size+1)*sizeof(char *));
    /* make a copy of each string */
    for (i=0; i<size; i++) {
        jstring j_string = (jstring)jenv->GetObjectArrayElement($input, i);
        const char * c_string = jenv->GetStringUTFChars(j_string, 0);
        $1[i] = (char *)malloc(strlen((c_string)+1)*sizeof(const char *));
        strcpy($1[i], c_string);
        jenv->ReleaseStringUTFChars(j_string, c_string);
        jenv->DeleteLocalRef(j_string);
    }
    $1[i] = 0;
}

/* This cleans up the memory we malloc'd before the function call */

%typemap(freearg) char ** {
    /* %typemap(freearg) char ** */
    int i;
    for (i=0; i<size$argnum-1; i++)
      free($1[i]);
    free($1);
}

/* This allows a C function to return a char ** as a Java String array */

%typemap(out, fragment="SafeNewStringUTF8") char ** {
    /* %typemap(out) char ** */
    int i;
    int len=0;
    jstring temp_string;
    const jclass clazz = jenv->FindClass("java/lang/String");

    while ($1[len]) len++;
    jresult = jenv->NewObjectArray(len, clazz, NULL);
    /* exception checking omitted */

    for (i=0; i<len; i++) {
      temp_string = SafeNewStringUTF8(jenv, *result++);
      jenv->SetObjectArrayElement(jresult, i, temp_string);
      jenv->DeleteLocalRef(temp_string);
    }
}

%typemap(jni) char ** "jobjectArray"
%typemap(jtype) char ** "String[]"
%typemap(jstype) char ** "String[]"
%typemap(javain) char ** "$javainput"
%typemap(javaout) char ** {
    return $jnicall;
  }

/***************************************************
 * Typemaps for (void * nioBuffer, size_t nioBufferSize)
 ***************************************************/

%typemap(in, numinputs=1) (void * nioBuffer, size_t nioBufferSize)
{
    /* %typemap(in, numinputs=1) (void * nioBuffer, size_t nioBufferSize) */
    if ($input == 0)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null array");
        return $null;
    }
    $1 = jenv->GetDirectBufferAddress($input);
    if ($1 == NULL)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException,
                                "Unable to get address of direct buffer. Buffer must be allocated direct.");
        return $null;
    }

    /* The cast to size_t is actually not that correct, but anyway afterwards */
    /* we check that the theoretical minimum buffer size is not larger than INT_MAX */
    /* so truncating to INT_MAX is OK */

    $2 = (size_t) ((jenv->GetDirectBufferCapacity($input) > INT_MAX) ? INT_MAX : jenv->GetDirectBufferCapacity($input));
}

/* These 3 typemaps tell SWIG what JNI and Java types to use */

%typemap(jni) (void * nioBuffer, size_t nioBufferSize)  "jobject"
%typemap(jtype) (void * nioBuffer, size_t nioBufferSize)  "java.nio.ByteBuffer"
%typemap(jstype) (void * nioBuffer, size_t nioBufferSize)  "java.nio.ByteBuffer"
%typemap(javain) (void * nioBuffer, size_t nioBufferSize)  "$javainput"
%typemap(javaout) (void * nioBuffer, size_t nioBufferSize) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for (ctype *regularArrayOut, size_t nRegularArraySizeOut)
 ***************************************************/

%define DEFINE_REGULAR_ARRAY_OUT(ctype, jtype, function)
%typemap(in, numinputs=1) (ctype *regularArrayOut, size_t nRegularArraySizeOut)
{
    if ($input == 0)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null array");
        return $null;
    }

    $2 = sizeof(ctype) * jenv->GetArrayLength($input);
    $1 = (ctype*) malloc($2);

    if ($1 == NULL)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException,
                                "Unable to allocate temporary buffer.");
        return $null;
    }
}

%typemap(freearg) (ctype *regularArrayOut, size_t nRegularArraySizeOut)
{
  if (result == CE_None)  // testing the CPL result
    jenv->function($input, (jsize)0, jenv->GetArrayLength($input), (jtype*)$1);

  free($1);
}

/* These 3 typemaps tell SWIG what JNI and Java types to use */

%typemap(javain) (ctype *regularArrayOut, size_t nRegularArraySizeOut)  "$javainput"
%typemap(javaout) (ctype *regularArrayOut, size_t nRegularArraySizeOut) {
    return $jnicall;
  }
%enddef

DEFINE_REGULAR_ARRAY_OUT(char, jbyte, SetByteArrayRegion);
%typemap(jni) (char *regularArrayOut, size_t nRegularArraySizeOut)  "jbyteArray"
%typemap(jtype) (char *regularArrayOut, size_t nRegularArraySizeOut)  "byte[]"
%typemap(jstype) (char *regularArrayOut, size_t nRegularArraySizeOut)  "byte[]"

DEFINE_REGULAR_ARRAY_OUT(short, jshort, SetShortArrayRegion);
%typemap(jni) (short *regularArrayOut, size_t nRegularArraySizeOut)  "jshortArray"
%typemap(jtype) (short *regularArrayOut, size_t nRegularArraySizeOut)  "short[]"
%typemap(jstype) (short *regularArrayOut, size_t nRegularArraySizeOut)  "short[]"

DEFINE_REGULAR_ARRAY_OUT(int, jint, SetIntArrayRegion);
%typemap(jni) (int *regularArrayOut, size_t nRegularArraySizeOut)  "jintArray"
%typemap(jtype) (int *regularArrayOut, size_t nRegularArraySizeOut)  "int[]"
%typemap(jstype) (int *regularArrayOut, size_t nRegularArraySizeOut)  "int[]"

DEFINE_REGULAR_ARRAY_OUT(int64_t, jlong, SetLongArrayRegion);
%typemap(jni) (int64_t *regularArrayOut, size_t nRegularArraySizeOut)  "jlongArray"
%typemap(jtype) (int64_t *regularArrayOut, size_t nRegularArraySizeOut)  "long[]"
%typemap(jstype) (int64_t *regularArrayOut, size_t nRegularArraySizeOut)  "long[]"

DEFINE_REGULAR_ARRAY_OUT(float, jfloat, SetFloatArrayRegion);
%typemap(jni) (float *regularArrayOut, size_t nRegularArraySizeOut)  "jfloatArray"
%typemap(jtype) (float *regularArrayOut, size_t nRegularArraySizeOut)  "float[]"
%typemap(jstype) (float *regularArrayOut, size_t nRegularArraySizeOut)  "float[]"

DEFINE_REGULAR_ARRAY_OUT(double, jdouble, SetDoubleArrayRegion);
%typemap(jni) (double *regularArrayOut, size_t nRegularArraySizeOut)  "jdoubleArray"
%typemap(jtype) (double *regularArrayOut, size_t nRegularArraySizeOut)  "double[]"
%typemap(jstype) (double *regularArrayOut, size_t nRegularArraySizeOut)  "double[]"


/***************************************************
 * Typemaps for (ctype *regularArrayIn, size_t nRegularArraySizeIn)
 ***************************************************/

%define DEFINE_REGULAR_ARRAY_IN(ctype, jtype, get_fct, release_fct)
%typemap(in, numinputs=1) (ctype *regularArrayIn, size_t nRegularArraySizeIn)
{
    if ($input == 0)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null array");
        return $null;
    }

    $2 = sizeof(ctype) * jenv->GetArrayLength($input);
    $1 = (ctype*) jenv->get_fct($input, 0);
    if ($1 == NULL)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException,
                                "Unable to get buffer.");
        return $null;
    }
}

%typemap(freearg) (ctype *regularArrayIn, size_t nRegularArraySizeIn)
{
  jenv->release_fct($input, (jtype*) $1, JNI_ABORT);
}


/* These 3 typemaps tell SWIG what JNI and Java types to use */

%typemap(javain) (ctype *regularArrayIn, size_t nRegularArraySizeIn)  "$javainput"
%typemap(javaout) (ctype *regularArrayIn, size_t nRegularArraySizeIn) {
    return $jnicall;
  }
%enddef

DEFINE_REGULAR_ARRAY_IN(char, jbyte, GetByteArrayElements, ReleaseByteArrayElements);
%typemap(jni) (char *regularArrayIn, size_t nRegularArraySizeIn)  "jbyteArray"
%typemap(jtype) (char *regularArrayIn, size_t nRegularArraySizeIn)  "byte[]"
%typemap(jstype) (char *regularArrayIn, size_t nRegularArraySizeIn)  "byte[]"

DEFINE_REGULAR_ARRAY_IN(short, jshort, GetShortArrayElements, ReleaseShortArrayElements);
%typemap(jni) (short *regularArrayIn, size_t nRegularArraySizeIn)  "jshortArray"
%typemap(jtype) (short *regularArrayIn, size_t nRegularArraySizeIn)  "short[]"
%typemap(jstype) (short *regularArrayIn, size_t nRegularArraySizeIn)  "short[]"

DEFINE_REGULAR_ARRAY_IN(int, jint, GetIntArrayElements, ReleaseIntArrayElements);
%typemap(jni) (int *regularArrayIn, size_t nRegularArraySizeIn)  "jintArray"
%typemap(jtype) (int *regularArrayIn, size_t nRegularArraySizeIn)  "int[]"
%typemap(jstype) (int *regularArrayIn, size_t nRegularArraySizeIn)  "int[]"

DEFINE_REGULAR_ARRAY_IN(int64_t, jlong, GetLongArrayElements, ReleaseLongArrayElements);
%typemap(jni) (int64_t *regularArrayIn, size_t nRegularArraySizeIn)  "jlongArray"
%typemap(jtype) (int64_t *regularArrayIn, size_t nRegularArraySizeIn)  "long[]"
%typemap(jstype) (int64_t *regularArrayIn, size_t nRegularArraySizeIn)  "long[]"

DEFINE_REGULAR_ARRAY_IN(float, jfloat, GetFloatArrayElements, ReleaseFloatArrayElements);
%typemap(jni) (float *regularArrayIn, size_t nRegularArraySizeIn)  "jfloatArray"
%typemap(jtype) (float *regularArrayIn, size_t nRegularArraySizeIn)  "float[]"
%typemap(jstype) (float *regularArrayIn, size_t nRegularArraySizeIn)  "float[]"

DEFINE_REGULAR_ARRAY_IN(double, jdouble, GetDoubleArrayElements, ReleaseDoubleArrayElements);
%typemap(jni) (double *regularArrayIn, size_t nRegularArraySizeIn)  "jdoubleArray"
%typemap(jtype) (double *regularArrayIn, size_t nRegularArraySizeIn)  "double[]"
%typemap(jstype) (double *regularArrayIn, size_t nRegularArraySizeIn)  "double[]"

/***************************************************
 * Typemaps for (ctype *arrayOut, size_t arraySize)
 ***************************************************/

%define DEFINE_BOOLEAN_FUNC_ARRAY_OUT(ctype, jtype, element_setter)
%typemap(in, numinputs=1) (ctype *arrayOut, size_t arraySize)
{
    if ($input == 0)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null array");
        return $null;
    }

    $2 = sizeof(ctype) * jenv->GetArrayLength($input);
    $1 = (ctype*) malloc($2);

    if ($1 == NULL)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException,
                                "Unable to allocate temporary buffer.");
        return $null;
    }
}

%typemap(freearg) (ctype *arrayOut, size_t arraySize)
{
  if (result)  // testing the boolean function result
    jenv->element_setter($input, (jsize)0, jenv->GetArrayLength($input), (jtype*)$1);

  free($1);
}

/* These 3 typemaps tell SWIG what JNI and Java types to use */

%typemap(javain) (ctype *arrayOut, size_t arraySize)  "$javainput"
%typemap(javaout) (ctype *arrayOut, size_t arraySize) {
    return $jnicall;
  }
%enddef

DEFINE_BOOLEAN_FUNC_ARRAY_OUT(char, jbyte, SetByteArrayRegion);
%typemap(jni) (char *arrayOut, size_t arraySize)  "jbyteArray"
%typemap(jtype) (char *arrayOut, size_t arraySize)  "byte[]"
%typemap(jstype) (char *arrayOut, size_t arraySize)  "byte[]"

DEFINE_BOOLEAN_FUNC_ARRAY_OUT(short, jshort, SetShortArrayRegion);
%typemap(jni) (short *arrayOut, size_t arraySize)  "jshortArray"
%typemap(jtype) (short *arrayOut, size_t arraySize)  "short[]"
%typemap(jstype) (short *arrayOut, size_t arraySize)  "short[]"

DEFINE_BOOLEAN_FUNC_ARRAY_OUT(int, jint, SetIntArrayRegion);
%typemap(jni) (int *arrayOut, size_t arraySize)  "jintArray"
%typemap(jtype) (int *arrayOut, size_t arraySize)  "int[]"
%typemap(jstype) (int *arrayOut, size_t arraySize)  "int[]"

DEFINE_BOOLEAN_FUNC_ARRAY_OUT(int64_t, jlong, SetLongArrayRegion);
%typemap(jni) (int64_t *arrayOut, size_t arraySize)  "jlongArray"
%typemap(jtype) (int64_t *arrayOut, size_t arraySize)  "long[]"
%typemap(jstype) (int64_t *arrayOut, size_t arraySize)  "long[]"

DEFINE_BOOLEAN_FUNC_ARRAY_OUT(float, jfloat, SetFloatArrayRegion);
%typemap(jni) (float *arrayOut, size_t arraySize)  "jfloatArray"
%typemap(jtype) (float *arrayOut, size_t arraySize)  "float[]"
%typemap(jstype) (float *arrayOut, size_t arraySize)  "float[]"

DEFINE_BOOLEAN_FUNC_ARRAY_OUT(double, jdouble, SetDoubleArrayRegion);
%typemap(jni) (double *arrayOut, size_t arraySize)  "jdoubleArray"
%typemap(jtype) (double *arrayOut, size_t arraySize)  "double[]"
%typemap(jstype) (double *arrayOut, size_t arraySize)  "double[]"


/***************************************************
 * Typemaps for (ctype *arrayIn, size_t arraySize)
 ***************************************************/

%define DEFINE_BOOLEAN_FUNC_ARRAY_IN(ctype, jtype, element_getter, element_releaser)
%typemap(in, numinputs=1) (ctype *arrayIn, size_t arraySize)
{
    if ($input == 0)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null array");
        return $null;
    }

    $2 = sizeof(ctype) * jenv->GetArrayLength($input);
    $1 = (ctype*) jenv->element_getter($input, 0);
    if ($1 == NULL)
    {
        SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException,
                                "Unable to get buffer.");
        return $null;
    }
}

%typemap(freearg) (ctype *arrayIn, size_t arraySize)
{
  jenv->element_releaser($input, (jtype*) $1, JNI_ABORT);
}

/* These 3 typemaps tell SWIG what JNI and Java types to use */

%typemap(javain) (ctype *arrayIn, size_t arraySize)  "$javainput"
%typemap(javaout) (ctype *arrayIn, size_t arraySize) {
    return $jnicall;
  }
%enddef

DEFINE_BOOLEAN_FUNC_ARRAY_IN(char, jbyte, GetByteArrayElements, ReleaseByteArrayElements);
%typemap(jni) (char *arrayIn, size_t arraySize)  "jbyteArray"
%typemap(jtype) (char *arrayIn, size_t arraySize)  "byte[]"
%typemap(jstype) (char *arrayIn, size_t arraySize)  "byte[]"

DEFINE_BOOLEAN_FUNC_ARRAY_IN(short, jshort, GetShortArrayElements, ReleaseShortArrayElements);
%typemap(jni) (short *arrayIn, size_t arraySize)  "jshortArray"
%typemap(jtype) (short *arrayIn, size_t arraySize)  "short[]"
%typemap(jstype) (short *arrayIn, size_t arraySize)  "short[]"

DEFINE_BOOLEAN_FUNC_ARRAY_IN(int, jint, GetIntArrayElements, ReleaseIntArrayElements);
%typemap(jni) (int *arrayIn, size_t arraySize)  "jintArray"
%typemap(jtype) (int *arrayIn, size_t arraySize)  "int[]"
%typemap(jstype) (int *arrayIn, size_t arraySize)  "int[]"

DEFINE_BOOLEAN_FUNC_ARRAY_IN(int64_t, jlong, GetLongArrayElements, ReleaseLongArrayElements);
%typemap(jni) (int64_t *arrayIn, size_t arraySize)  "jlongArray"
%typemap(jtype) (int64_t *arrayIn, size_t arraySize)  "long[]"
%typemap(jstype) (int64_t *arrayIn, size_t arraySize)  "long[]"

DEFINE_BOOLEAN_FUNC_ARRAY_IN(float, jfloat, GetFloatArrayElements, ReleaseFloatArrayElements);
%typemap(jni) (float *arrayIn, size_t arraySize)  "jfloatArray"
%typemap(jtype) (float *arrayIn, size_t arraySize)  "float[]"
%typemap(jstype) (float *arrayIn, size_t arraySize)  "float[]"

DEFINE_BOOLEAN_FUNC_ARRAY_IN(double, jdouble, GetDoubleArrayElements, ReleaseDoubleArrayElements);
%typemap(jni) (double *arrayIn, size_t arraySize)  "jdoubleArray"
%typemap(jtype) (double *arrayIn, size_t arraySize)  "double[]"
%typemap(jstype) (double *arrayIn, size_t arraySize)  "double[]"

/***************************************************
 * Typemaps for GIntBig
 ***************************************************/

%typemap(in) (GIntBig)
{
  /* %typemap(in) (GIntBig) */
  $1 = (GIntBig) $input;
}

%typemap(out) (GIntBig)
{
  /* %typemap(out) (GIntBig) */
  $result = (jlong) $1;
}

%typemap(jni) (GIntBig) "jlong"
%typemap(jtype) (GIntBig) "long"
%typemap(jstype) (GIntBig) "long"
%typemap(javain) (GIntBig) "$javainput"
%typemap(javaout) (GIntBig) {
  return $jnicall;
}

/***************************************************
 * Typemaps for GUIntBig
 ***************************************************/

%typemap(in) (GUIntBig)
{
  /* %typemap(in) (GUIntBig) */
  $1 = (GUIntBig) $input;
}

%typemap(out) (GUIntBig)
{
  /* %typemap(out) (GUIntBig) */
  $result = (jlong) $1;
}

%typemap(jni) (GUIntBig) "jlong"
%typemap(jtype) (GUIntBig) "long"
%typemap(jstype) (GUIntBig) "long"
%typemap(javain) (GUIntBig) "$javainput"
%typemap(javaout) (GUIntBig) {
  return $jnicall;
}

/***************************************************
 * Typemaps for GInt64
 ***************************************************/

%typemap(in) (GInt64)
{
  /* %typemap(in) (GInt64) */
  $1 = (GInt64) $input;
}

%typemap(out) (GInt64)
{
  /* %typemap(out) (GInt64) */
  $result = (jlong) $1;
}

%typemap(jni) (GInt64) "jlong"
%typemap(jtype) (GInt64) "long"
%typemap(jstype) (GInt64) "long"
%typemap(javain) (GInt64) "$javainput"
%typemap(javaout) (GInt64) {
  return $jnicall;
}

/***************************************************
 * Typemaps for GUInt64
 ***************************************************/

%typemap(in) (GUInt64)
{
  /* %typemap(in) (GUInt64) */
  $1 = (GUInt64) $input;
}

%typemap(out) (GUInt64)
{
  /* %typemap(out) (GUInt64) */
  $result = (jlong) $1;
}

%typemap(jni) (GUInt64) "jlong"
%typemap(jtype) (GUInt64) "long"
%typemap(jstype) (GUInt64) "long"
%typemap(javain) (GUInt64) "$javainput"
%typemap(javaout) (GUInt64) {
  return $jnicall;
}

/***************************************************
 * Typemaps for ( int nCount, double *x, double *y, double *z )
 ***************************************************/

%typemap(in) ( int nCount, double *x, double *y, double *z ) (int xyzLen)
{
    /* %typemap(in) ( int nCount, double *x, double *y, double *z ) */
    $1 = ($input) ? jenv->GetArrayLength($input) : 0;
    xyzLen = $1;
    $2 = (double*)CPLMalloc($1 * sizeof(double));
    $3 = (double*)CPLMalloc($1 * sizeof(double));
    $4 = (double*)CPLMalloc($1 * sizeof(double));
    int i;
    for (i=0; i<$1; i++) {
        jdoubleArray doubleArray = (jdoubleArray)jenv->GetObjectArrayElement($input, i);
        if (doubleArray == NULL)
        {
            CPLFree ($2);
            CPLFree ($3);
            CPLFree ($4);
            SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null object in array");
            return $null;
        }
        int nDim = jenv->GetArrayLength(doubleArray);
        if (nDim != 2 && nDim != 3)
        {
            CPLFree ($2);
            CPLFree ($3);
            CPLFree ($4);
            SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "wrong array dimensions");
            return $null;
        }
        double* pElements = jenv->GetDoubleArrayElements(doubleArray, NULL);
        $2[i] = pElements[0];
        $3[i] = pElements[1];
        if (nDim == 3)
            $4[i] = pElements[2];
        else
            $4[i] = 0;
        jenv->ReleaseDoubleArrayElements(doubleArray, pElements, JNI_ABORT);
    }
}

%typemap(argout) ( int nCount, double *x, double *y, double *z )
{
    /* %typemap(argout) ( int nCount, double *x, double *y, double *z ) */
    int i;
    for (i=0; i<$1; i++) {
        jdoubleArray doubleArray = (jdoubleArray)jenv->GetObjectArrayElement($input, i);
        int nDim = jenv->GetArrayLength(doubleArray);
        jenv->SetDoubleArrayRegion(doubleArray, (jsize)0, (jsize)1, &$2[i]);
        jenv->SetDoubleArrayRegion(doubleArray, (jsize)1, (jsize)1, &$3[i]);
        if (nDim == 3)
                jenv->SetDoubleArrayRegion(doubleArray, (jsize)2, (jsize)1, &$4[i]);
    }
    CPLFree($2);
    CPLFree($3);
    CPLFree($4);
}

%typemap(jni) ( int nCount, double *x, double *y, double *z ) "jobjectArray"
%typemap(jtype) ( int nCount, double *x, double *y, double *z ) "double[][]"
%typemap(jstype) ( int nCount, double *x, double *y, double *z ) "double[][]"
%typemap(javain) ( int nCount, double *x, double *y, double *z ) "$javainput"
%typemap(javaout) ( int nCount, double *x, double *y, double *z ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for ( int nCount, double *x, double *y, double *z, double *t )
 ***************************************************/

%typemap(in) ( int nCount, double *x, double *y, double *z, double *t ) (int xyzLen)
{
    /* %typemap(in) ( int nCount, double *x, double *y, double *z, double *t ) */
    $1 = ($input) ? jenv->GetArrayLength($input) : 0;
    xyzLen = $1;
    $2 = (double*)CPLMalloc($1 * sizeof(double));
    $3 = (double*)CPLMalloc($1 * sizeof(double));
    $4 = (double*)CPLMalloc($1 * sizeof(double));
    $5 = (double*)CPLMalloc($1 * sizeof(double));
    int i;
    for (i=0; i<$1; i++) {
        jdoubleArray doubleArray = (jdoubleArray)jenv->GetObjectArrayElement($input, i);
        if (doubleArray == NULL)
        {
            CPLFree ($2);
            CPLFree ($3);
            CPLFree ($4);
            CPLFree ($5);
            SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null object in array");
            return $null;
        }
        int nDim = jenv->GetArrayLength(doubleArray);
        if (nDim != 2 && nDim != 3 && nDim != 4)
        {
            CPLFree ($2);
            CPLFree ($3);
            CPLFree ($4);
            CPLFree ($5);
            SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "wrong array dimensions");
            return $null;
        }
        double* pElements = jenv->GetDoubleArrayElements(doubleArray, NULL);
        $2[i] = pElements[0];
        $3[i] = pElements[1];
        if (nDim == 3 || nDim == 4)
            $4[i] = pElements[2];
        else
            $4[i] = 0;
        if (nDim == 4)
            $5[i] = pElements[3];
        else
            $5[i] = 0;
        jenv->ReleaseDoubleArrayElements(doubleArray, pElements, JNI_ABORT);
    }
}

%typemap(argout) ( int nCount, double *x, double *y, double *z, double *t )
{
    /* %typemap(argout) ( int nCount, double *x, double *y, double *z, double *t ) */
    int i;
    for (i=0; i<$1; i++) {
        jdoubleArray doubleArray = (jdoubleArray)jenv->GetObjectArrayElement($input, i);
        int nDim = jenv->GetArrayLength(doubleArray);
        jenv->SetDoubleArrayRegion(doubleArray, (jsize)0, (jsize)1, &$2[i]);
        jenv->SetDoubleArrayRegion(doubleArray, (jsize)1, (jsize)1, &$3[i]);
        if (nDim == 3 || nDim == 4)
            jenv->SetDoubleArrayRegion(doubleArray, (jsize)2, (jsize)1, &$4[i]);
        if (nDim == 4)
            jenv->SetDoubleArrayRegion(doubleArray, (jsize)3, (jsize)1, &$5[i]);
    }
    CPLFree($2);
    CPLFree($3);
    CPLFree($4);
    CPLFree($5);
}

%typemap(jni) ( int nCount, double *x, double *y, double *z, double *t ) "jobjectArray"
%typemap(jtype) ( int nCount, double *x, double *y, double *z, double *t ) "double[][]"
%typemap(jstype) ( int nCount, double *x, double *y, double *z, double *t ) "double[][]"
%typemap(javain) ( int nCount, double *x, double *y, double *z, double *t ) "$javainput"

%typemap(in,numinputs=0) (int* pnCountOut, int** outErrorCodes) ( int nPoints = 0, int* errorCodes = NULL )
{
  /* %typemap(in,numinputs=0) (int* pnCountOut, int** outErrorCodes) */
  $1 = &nPoints;
  $2 = &errorCodes;
}

%typemap(argout) (int* pnCountOut, int** outErrorCodes)
{
  /* %typemap(argout) (int* pnCountOut, int** outErrorCodes) */
  int nPointCount = *($1);
  const int* errorCodes = *($2);
  jintArray intArray = jenv->NewIntArray(nPointCount);
  jenv->SetIntArrayRegion(intArray, (jsize)0, (jsize)nPointCount, (jint*)errorCodes);
  *(jintArray *)&jresult = intArray;
}

%typemap(freearg) (int* pnCountOut, int** outErrorCodes)
{
  /* %typemap(freearg) (int* pnCountOut, int** outErrorCodes) */
  int* errorCodes = *($2);
  VSIFree(errorCodes);
}

%typemap(jni) (int* pnCountOut, int** outErrorCodes) "jintArray"
%typemap(jtype) (int* pnCountOut, int** outErrorCodes) "int[]"
%typemap(jstype) (int* pnCountOut, int** outErrorCodes) "int[]"
%typemap(javain) (int* pnCountOut, int** outErrorCodes) "$javainput"
%typemap(javaout) (int* pnCountOut, int** outErrorCodes) {
    return $jnicall;
  }


%typemap(jni) ( int *outIntArray ) "jintArray"
%typemap(jtype) ( int *outIntArray ) "int[]"
%typemap(jstype) ( int *outIntArray ) "int[]"
%typemap(javain) ( int *outIntArray ) "$javainput"
%typemap(javaout) ( int *outIntArray ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for ( int *panSuccess )
 ***************************************************/

%typemap(in) ( int *panSuccess )
{
    /* %typemap(in) ( int *panSuccess ) */
    if ($input == NULL)
    {
        $1 = (int*)CPLCalloc(xyzLen3, sizeof(int));
    }
    else
    {
        int len = jenv->GetArrayLength($input);
        /* HACK */
        if (len != xyzLen3)
        {
            SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "wrong array dimensions");
            return $null;
        }
        $1 = (int*)CPLCalloc(len, sizeof(int));
    }
}

%typemap(argout) ( int *panSuccess )
{
    /* %typemap(argout) ( int *panSuccess ) */
    if ($input)
        jenv->SetIntArrayRegion($input, (jsize)0, (jsize)xyzLen3, (jint*)$1);
    CPLFree($1);
}

%typemap(jni) ( int *panSuccess ) "jintArray"
%typemap(jtype) ( int *panSuccess ) "int[]"
%typemap(jstype) ( int *panSuccess ) "int[]"
%typemap(javain) ( int *panSuccess ) "$javainput"
%typemap(javaout) ( int *panSuccess ) {
    return $jnicall;
  }

/***************************************************
 * Typemaps for Geometry.GetPoints()
 ***************************************************/

%typemap(in,numinputs=0) (int* pnCount, double** ppadfXY, double** ppadfZ) ( int nPoints = 0, double* padfXY = NULL, double* padfZ = NULL)
{
  /* %typemap(in,numinputs=0) (int* pnCount, double** ppadfXY, double** ppadfZ) */
  $1 = &nPoints;
  $2 = &padfXY;
  $3 = &padfZ;
}

%typemap(argout) (int* pnCount, double** ppadfXY, double** ppadfZ)
{
  /* %typemap(argout) (int* pnCount, double** ppadfXY, double** ppadfZ) */
  int nPointCount = *($1);
  if (nPointCount == 0)
  {
    $result = 0;
  }
  else
  {
    int nDimensions = (*$3 != NULL) ? 3 : 2;
    $result = jenv->NewObjectArray(nPointCount, jenv->FindClass("java/lang/Object"), NULL);
    int i;
    for (i=0; i<nPointCount; i++ )
    {
        jdoubleArray dblArray = jenv->NewDoubleArray(nDimensions);
        jenv->SetDoubleArrayRegion(dblArray, 0, 2, &( (*$2)[2*i] ));
        if (nDimensions == 3)
            jenv->SetDoubleArrayRegion(dblArray, 2, 1, &( (*$3)[i] ));
        jenv->SetObjectArrayElement($result, (jsize)i, dblArray);
        jenv->DeleteLocalRef(dblArray);
    }
  }
}

%typemap(freearg) (int* pnCount, double** ppadfXY, double** ppadfZ)
{
    /* %typemap(freearg) (int* pnCount, double** ppadfXY, double** ppadfZ) */
    VSIFree(*$2);
    VSIFree(*$3);
}

%typemap(argout) (retGetPoints*)
{
  /* %typemap(argout) (retGetPoints*) */
}

%typemap(jni) ( retGetPoints* ) "jobjectArray"
%typemap(jtype) ( retGetPoints* ) "double[][]"
%typemap(jstype) ( retGetPoints* ) "double[][]"
%typemap(javain) ( retGetPoints* ) "$javainput"
%typemap(javaout) ( retGetPoints* ) {
    return $jnicall;
  }

/*******************************************************
   Typemap notes
 *******************************************************/

//  useful docs: https://www.swig.org/Doc1.3/Typemaps.html

//investigate
//  do we have to mess with numinputs? it must be = 0, 1, or not present.
//  what effects do the options have?

// argout is for code that does java manipulations.
//   if it ends up with a $result it is a java object
// out seems exactly the same. why are there two?
//   why choose one over the other?

// typemap(in)  (type list): convert from Java to C
// typemap(out) (type list): convert from C to Java


/***** Dimension typemaps *****************************/

/*
  From Java: Dimension[]
  To C:      (int object_list_count, GDALDimensionHS **poObjects)
*/

%typemap(in, numinputs=1) (int object_list_count, GDALDimensionHS **poObjects)
{
  /* %typemap(in, numinputs=1) (int object_list_count, GDALDimensionHS **poObjects) */
  if ($input)
  {
    const jclass dimClass = jenv->FindClass("org/gdal/gdal/Dimension");
    const jmethodID getCPtr = jenv->GetStaticMethodID(dimClass, "getCPtr", "(Lorg/gdal/gdal/Dimension;)J");

    $1 = jenv->GetArrayLength($input);
    if ($1 == 0) {
       $2 = NULL;
    }
    else
    {
        $2 = (GDALDimensionH*) malloc(sizeof(GDALDimensionH) * $1);

        int i;
        for (i=0; i<$1; i++) {
            jobject obj = jenv->GetObjectArrayElement($input, i);
            if (obj == NULL)
            {
                free($2);
                SWIG_JavaThrowException(jenv, SWIG_JavaNullPointerException, "null object in array");
                return $null;
            }
            $2[i] = (GDALDimensionH) jenv->CallStaticLongMethod(dimClass, getCPtr, obj);
        }
    }
  }
  else
  {
    $1 = 0;
    $2 = (GDALDimensionH*) NULL;
  }
}

/*
  From C: (int object_list_count, GDALDimensionHS **poObjects)
  To Java: Dimension[]
*/

%typemap(out) (int object_list_count, GDALDimensionHS **poObjects)
{
  /* %typemap(out) (int object_list_count, GDALDimensionHS **poObjects) */
  const jclass dimClass = jenv->FindClass("org/gdal/gdal/Dimension");
  const jmethodID dCtor = jenv->GetMethodID(dimClass, "<init>", "(JZ)V");

  $result = jenv->NewObjectArray($1, dimClass, NULL);

  int i;
  for (i=0; i<$1; i++) {

    GDALDimensionH gDimH = $2[i];

    jobject dimension = jenv->NewObject(dimClass, dCtor, gDimH, false);

    jenv->SetObjectArrayValue($result, i, dimension);
  }
}

%typemap(freearg) (int object_list_count, GDALDimensionHS **poObjects)
{
  /* %typemap(freearg) (int object_list_count, GDALDimensionHS **poObjects) */
  if ($2) {

    free((void*) $2);
  }
}

%typemap(jni) (int object_list_count, GDALDimensionHS **poObjects) "jobjectArray"
%typemap(jtype) (int object_list_count, GDALDimensionHS **poObjects) "org.gdal.gdal.Dimension[]"
%typemap(jstype) (int object_list_count, GDALDimensionHS **poObjects) "org.gdal.gdal.Dimension[]"
%typemap(javain) (int object_list_count, GDALDimensionHS **poObjects) "$javainput"
%typemap(javaout) (int object_list_count, GDALDimensionHS **poObjects) {
    return $jnicall;
}

/***** int, GInt64* typemaps *******************************/

%typemap(in, numinputs=1) (int nList, GInt64 *pList)
{
  /* %typemap(in, numinputs=1) (int nList, GInt64 *pList) */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = (GInt64 *) NULL;
    else
       $2 = (GInt64 *) jenv->GetLongArrayElements($input, NULL);
  }
  else {
    $1 = 0;
    $2 = (GInt64 *) NULL;
  }
}

%typemap(freearg) (int nList, GInt64 *pList)
{
  /* %typemap(freearg) (int nList, GInt64 *pList) */
  if ($2) {
    jenv->ReleaseLongArrayElements($input, (jlong*)$2, JNI_ABORT);
  }
}

%typemap(jni) (int nList, GInt64 *pList) "jlongArray"
%typemap(jtype) (int nList, GInt64 *pList) "long[]"
%typemap(jstype) (int nList, GInt64 *pList) "long[]"
%typemap(javain) (int nList, GInt64 *pList) "$javainput"
%typemap(javaout) (int nList, GInt64 *pList) {
    return $jnicall;
}

/***** int, GUInt64* typemaps *******************************/

%typemap(in, numinputs=1) (int nList, GUInt64 *pList)
{
  /* %typemap(in, numinputs=1) (int nList, GUInt64 *pList) */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = (GUInt64 *) NULL;
    else
       $2 = (GUInt64 *) jenv->GetLongArrayElements($input, NULL);
  }
  else {
    $1 = 0;
    $2 = (GUInt64 *) NULL;
  }
}

%typemap(freearg) (int nList, GUInt64 *pList)
{
  /* %typemap(freearg) (int nList, GUInt64 *pList) */
  if ($2) {
    jenv->ReleaseLongArrayElements($input, (jlong*)$2, JNI_ABORT);
  }
}

%typemap(jni) (int nList, GUInt64 *pList) "jlongArray"
%typemap(jtype) (int nList, GUInt64 *pList) "long[]"
%typemap(jstype) (int nList, GUInt64 *pList) "long[]"
%typemap(javain) (int nList, GUInt64 *pList) "$javainput"
%typemap(javaout) (int nList, GUInt64 *pList) {
    return $jnicall;
}

/***** int, GUIntBig* typemaps *******************************/

%typemap(in, numinputs=1) (int nList, GUIntBig *pList)
{
  /* %typemap(in, numinputs=1) (int nList, GUIntBig *pList) */
  if ($input)
  {
    $1 = jenv->GetArrayLength($input);
    if ($1 == 0)
       $2 = (GUIntBig *) NULL;
    else
       $2 = (GUIntBig *) jenv->GetLongArrayElements($input, NULL);
  }
  else {
    $1 = 0;
    $2 = (GUIntBig *) NULL;
  }
}

%typemap(freearg) (int nList, GUIntBig *pList)
{
  /* %typemap(freearg) (int nList, GUIntBig *pList) */
  if ($2) {
    jenv->ReleaseLongArrayElements($input, (jlong*)$2, JNI_ABORT);
  }
}

%typemap(jni) (int nList, GUIntBig *pList) "jlongArray"
%typemap(jtype) (int nList, GUIntBig *pList) "long[]"
%typemap(jstype) (int nList, GUIntBig *pList) "long[]"
%typemap(javain) (int nList, GUIntBig *pList) "$javainput"
%typemap(javaout) (int nList, GUIntBig *pList) {
    return $jnicall;
}

/***************************************************
 * Typemaps converts a HashMap to a OGRCodedValue*
 ***************************************************/

%typemap(in) OGRCodedValue*
{
  /* %typemap(in) OGRCodedValue* */
  /* Convert the HashMap to a OGRCodedValue* */
  $1 = NULL;
  if($input != 0) {
    const jclass hashmapCass = jenv->FindClass("java/util/HashMap");
    const jclass setClass = jenv->FindClass("java/util/Set");
    const jclass iteratorClass = jenv->FindClass("java/util/Iterator");
    const jclass stringClass = jenv->FindClass("java/lang/String");
    const jmethodID sizeMethod = jenv->GetMethodID(hashmapCass, "size", "()I");
    const jmethodID getMethod = jenv->GetMethodID(hashmapCass, "get",
      "(Ljava/lang/Object;)Ljava/lang/Object;");
    const jmethodID keySetMethod = jenv->GetMethodID(hashmapCass, "keySet",
      "()Ljava/util/Set;");
    const jmethodID iteratorMethod = jenv->GetMethodID(setClass, "iterator",
      "()Ljava/util/Iterator;");
    const jmethodID hasNextMethod = jenv->GetMethodID(iteratorClass,
      "hasNext", "()Z");
    const jmethodID nextMethod = jenv->GetMethodID(iteratorClass,
      "next", "()Ljava/lang/Object;");

    int size = jenv->CallIntMethod($input, sizeMethod);
    $1 = (OGRCodedValue*)CPLCalloc(size+1, sizeof(OGRCodedValue) );

    jobject keyset = jenv->CallObjectMethod($input, keySetMethod);
    jobject iterator = jenv->CallObjectMethod(keyset, iteratorMethod);
    int i = 0;
    while( jenv->CallBooleanMethod(iterator, hasNextMethod) == JNI_TRUE ) {
      jstring key = (jstring)jenv->CallObjectMethod(iterator, nextMethod);
      if (key == NULL || !jenv->IsInstanceOf(key, stringClass))
      {
          for( int j = 0; j < i; ++j )
          {
              CPLFree(($1)[j].pszCode);
              CPLFree(($1)[j].pszValue);
          }
          CPLFree($1);
          SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "a key in the HashMap is not a string");
          return $null;
      }
      jstring value = (jstring)jenv->CallObjectMethod($input, getMethod, key);
      if (value != NULL && !jenv->IsInstanceOf(value, stringClass))
      {
          for( int j = 0; j < i; ++j )
          {
              CPLFree(($1)[j].pszCode);
              CPLFree(($1)[j].pszValue);
          }
          CPLFree($1);
          SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "a value in the HashMap is not a string");
          return $null;
      }
      const char *keyptr = jenv->GetStringUTFChars(key, 0);
      ($1)[i].pszCode = CPLStrdup(keyptr);
      if( value )
      {
          const char *valptr = jenv->GetStringUTFChars(value, 0);
          ($1)[i].pszValue = CPLStrdup(valptr);
          jenv->ReleaseStringUTFChars(value, valptr);
      }
      else
      {
          ($1)[i].pszValue = NULL;
      }
      ++i;
      jenv->ReleaseStringUTFChars(key, keyptr);
    }
  }
}

%typemap(freearg) OGRCodedValue*
{
  /* %typemap(freearg) OGRCodedValue* */
  if( $1 )
  {
      for( size_t i = 0; ($1)[i].pszCode != NULL; ++i )
      {
          CPLFree(($1)[i].pszCode);
          CPLFree(($1)[i].pszValue);
      }
  }
  CPLFree( $1 );
}

%typemap(out, fragment="SafeNewStringUTF8") OGRCodedValue*
{
  /* %typemap(out) OGRCodedValue* */
  /* Convert a OGRCodedValue* to a HashMap */
  if( $1 == NULL )
  {
      SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, CPLGetLastErrorMsg() );
      return $null;
  }
  const jclass hashMapClass = jenv->FindClass("java/util/HashMap");
  const jmethodID constructor = jenv->GetMethodID(hashMapClass, "<init>", "()V");
  const jmethodID put = jenv->GetMethodID(hashMapClass, "put",
    "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  $result = jenv->NewObject(hashMapClass, constructor);
  for( int i = 0; ($1)[i].pszCode != NULL; i++ )
  {
    jstring name = SafeNewStringUTF8(jenv, ($1)[i].pszCode);
    if( ($1)[i].pszValue )
    {
        jstring value = SafeNewStringUTF8(jenv, ($1)[i].pszValue);
        jenv->CallObjectMethod($result, put, name, value);
        jenv->DeleteLocalRef(value);
    }
    else
    {
        jenv->CallObjectMethod($result, put, name, NULL);
    }
    jenv->DeleteLocalRef(name);
  }
}

%typemap(jni) (OGRCodedValue*) "jobject"
%typemap(jtype) (OGRCodedValue*) "java.util.HashMap<String, String>"
%typemap(jstype) (OGRCodedValue*) "java.util.HashMap<String, String>"
%typemap(javain) (OGRCodedValue*) "$javainput"
%typemap(javaout) (OGRCodedValue*) {
    return $jnicall;
  }
