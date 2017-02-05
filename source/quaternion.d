import std.math: abs, acos, approxEqual, cos, PI, sin, sqrt;
import matrix4x4;
import vec3;

struct Quaternion
{
    this( float ax, float ay, float az )
    {
        x = ax;
        y = ay;
        z = az;
    }

    this( Vec3 v, float w )
    {
        x = v.x;
        y = v.y;
        z = v.z;
        this.w = w;
    }

    pragma( inline ) Vec3 opBinary( string op )( const( Vec3 ) v ) const
    {
        static if (op == "*")
        {
            const Vec3 wComponent = Vec3( w, w, w );
            const Vec3 two = Vec3( 2.0f, 2.0f, 2.0f );

            const Vec3 vT = two * cross( Vec3( x, y, z ), v );
            return v + (wComponent * vT) + cross( Vec3( x, y, z ), vT );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    Vec3 opBinary( string op )( float f ) const
    {
        /*static if (op == "*")
        {
        }
        else */static assert( false, "operator " ~ op ~ " not implemented" );
    }

    Quaternion opBinary( string op )( Quaternion aQ ) const
    {
        static if (op == "*")
        {
            return Quaternion( Vec3( w * aQ.x + x * aQ.w + y * aQ.z - z * aQ.y,
                                     w * aQ.y + y * aQ.w + z * aQ.x - x * aQ.z,
                                    w * aQ.z + z * aQ.w + x * aQ.y - y * aQ.x ),
                               w * aQ.w - x * aQ.x - y * aQ.y - z * aQ.z );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    public void normalize()
    {
        const float mag2 = w * w + x * x + y * y + z * z;
        const float acceptableDelta = 0.00001f;

        if (abs( mag2 ) > acceptableDelta && abs( mag2 - 1.0f ) > acceptableDelta)
        {
            const float oneOverMag = 1.0f / sqrt( mag2 );

            x *= oneOverMag;
            y *= oneOverMag;
            z *= oneOverMag;
            w *= oneOverMag;
        }
    }

    public float findTwist( Vec3 axis ) const
    {
        // Get the plane the axis is a normal of.
        Vec3 orthonormal1, orthonormal2;
        findOrthonormals( axis, orthonormal1, orthonormal2 );

        Vec3 transformed = this * orthonormal1;

        //project transformed vector onto plane
        Vec3 flattened = transformed - axis * dot( transformed, axis );
        flattened.normalize();

        // get angle between original vector and projected transform to get angle around normal
        return acos( dot( orthonormal1, flattened ) );
    }

    public void fromAxisAngle( Vec3 axis, float angleDeg )
    {
        float angleRad = angleDeg * (PI / 180);

        angleRad *= 0.5f;

        const float sinAngle = sin( angleRad );

        x = axis.x * sinAngle;
        y = axis.y * sinAngle;
        z = axis.z * sinAngle;
        w = cos( angleRad );
    }

    public void fromMatrix( Matrix4x4 mat )
    {
        float t;

        if (mat.m[ 10 ] < 0)
        {
            if (mat.m[ 0 ] > mat.m[ 5 ])
            {
                t = 1 + mat.m[ 0 ] - mat.m[ 5 ] - mat.m[ 10 ];
                this = Quaternion( Vec3( t, mat.m[ 1 ] + mat.m[ 4 ], mat.m[ 8 ] + mat.m[ 2 ] ), mat.m[ 6 ] - mat.m[ 9 ] );
            }
            else
            {
                t = 1 - mat.m[ 0 ] + mat.m[ 5 ] - mat.m[ 10 ];
                this = Quaternion( Vec3( mat.m[ 1 ] + mat.m[ 4 ], t, mat.m[ 6 ] + mat.m[ 9 ] ), mat.m[ 8 ] - mat.m[ 2 ] );
            }
        }
        else
        {
            if (mat.m[ 0 ] < -mat.m[ 5 ])
            {
                t = 1 - mat.m[ 0 ] - mat.m[ 5 ] + mat.m[ 10 ];
                this = Quaternion( Vec3( mat.m[ 8 ] + mat.m[ 2 ], mat.m[ 6 ] + mat.m[ 9 ], t ), mat.m[ 1 ] - mat.m[ 4 ] );
            }
            else
            {
                t = 1 + mat.m[ 0 ] + mat.m[ 5 ] + mat.m[ 10 ];
                this = Quaternion( Vec3( mat.m[ 6 ] - mat.m[ 9 ], mat.m[ 8 ] - mat.m[ 2 ], mat.m[ 1 ] - mat.m[ 4 ] ), t );
            }
        }

        const float factor = 0.5f / sqrt( t );
        x *= factor;
        y *= factor;
        z *= factor;
        w *= factor;
    }

    public void getMatrix( out Matrix4x4 outMatrix )
    {
        const float x2 = x * x;
        const float y2 = y * y;
        const float z2 = z * z;
        const float xy = x * y;
        const float xz = x * z;
        const float yz = y * z;
        const float wx = w * x;
        const float wy = w * y;
        const float wz = w * z;

        outMatrix.m[ 0] = 1 - 2 * (y2 + z2);
        outMatrix.m[ 1] = 2 * (xy - wz);
        outMatrix.m[ 2] = 2 * (xz + wy);
        outMatrix.m[ 3] = 0;
        outMatrix.m[ 4] = 2 * (xy + wz);
        outMatrix.m[ 5] = 1 - 2 * (x2 + z2);
        outMatrix.m[ 6] = 2 * (yz - wx);
        outMatrix.m[ 7] = 0;
        outMatrix.m[ 8] = 2 * (xz - wy);
        outMatrix.m[ 9] = 2 * (yz + wx);
        outMatrix.m[10] = 1 - 2 * (x2 + y2);
        outMatrix.m[11] = 0;
        outMatrix.m[12] = 0;
        outMatrix.m[13] = 0;
        outMatrix.m[14] = 0;
        outMatrix.m[15] = 1;
    }

    private void findOrthonormals( out Vec3 normal, out Vec3 orthonormal1, out Vec3 orthonormal2 ) const
    {
        Matrix4x4 orthoX = Matrix4x4( 90,  0, 0 );
        Matrix4x4 orthoY = Matrix4x4(  0, 90, 0 );

        Vec3 ww;
        transformDirection( normal, orthoX, ww );
        const float dot = dot( normal, ww );

        if (abs( dot ) > 0.6f)
        {
            transformDirection( normal, orthoY, ww );
        }

        ww.normalize();

        orthonormal1 = cross( normal, ww );
        orthonormal1.normalize();
        orthonormal2 = cross( normal, orthonormal1 );
        orthonormal2.normalize();
    }

    float x = 0, y = 0, z = 0, w = 1;
}

unittest
{
    Quaternion q = Quaternion( Vec3( 2.5f, -1.3f, -5.2f ), 1.8f );
    q.normalize();

    assert( approxEqual( q.x, 0.404385f ) &&
            approxEqual( q.y, -0.21028f ) &&
            approxEqual( q.z, -0.84112f ) &&
            approxEqual( q.w, 0.291157f ) );
}

unittest
{
    const Quaternion q1 = Quaternion( Vec3( 2.5f, -1.3f, -5.2f ), 1.0f );
    const Quaternion q2 = Quaternion( Vec3( 5.4f, 2.6f, 6.7f ), 1.0f );

    const Quaternion result = q1 * q2;

    const float acceptableDelta = 0.00001f;

    assert( !(result.w - 25.72f > acceptableDelta ||
                 result.x - 12.71f > acceptableDelta ||
                result.y + 43.53f > acceptableDelta ||
                result.z - 15.02f > acceptableDelta ));
}
