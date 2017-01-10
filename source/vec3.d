import std.math: abs, approxEqual, sqrt;

public Vec3 cross( Vec3 v1, Vec3 v2 )
{
    return Vec3( v1.y * v2.z - v1.z * v2.y,
                 v1.z * v2.x - v1.x * v2.z,
                 v1.x * v2.y - v1.y * v2.x );
}

public float dot( Vec3 v1, Vec3 v2 )
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z; 
}

public void normalize( ref Vec3 v )
{
    const float len = length( v );
    //assert( approxEqual( len, 0.0f ), "length is 0" );
    v.x /= len;
    v.y /= len;
    v.z /= len;
}

public float length( ref Vec3 v )
{
    return sqrt( v.x * v.x + v.y * v.y + v.z * v.z );
}

private bool isAlmost( Vec3 v1, Vec3 v2 )
{
    return approxEqual( v1.x, v2.x ) && approxEqual( v1.y, v2.y ) && approxEqual( v1.z, v2.z );
}

struct Vec3
{
    this( float ax, float ay, float az )
    {
        x = ax;
        y = ay;
        z = az;
    }

    Vec3 opBinary( string op )( Vec3 v ) const
    {
        static if (op == "+")
        {
            return Vec3( x + v.x, y + v.y, z + v.z );
        }
        else static if (op == "-")
        {
            return Vec3( x - v.x, y - v.y, z - v.z );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    Vec3 opBinary( string op )( float f ) const
    {
        static if (op == "*")
        {
            return Vec3( x * f, y * f, z * f );
        }
        else static if (op == "/")
        {
            return Vec3( x / f, y / f, z / f );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    public float maxComponent() const
    {
        float maxComp = x;

        if (y > maxComp)
        {
            maxComp = y;
        }

        if (z > maxComp)
        {
            maxComp = z;
        }

        return maxComp;
    }

    float x = 0, y = 0, z = 0;
}

unittest
{
    Vec3 v = Vec3( 6, 6, 6 );
    normalize( v );
    assert( approxEqual( length( v ), 1 ), "Vec3 Length failed" );

    assert( isAlmost( cross( Vec3( 1, 0, 0 ), Vec3( 0, 1, 0 ) ), Vec3( 0, 0, 1 ) ), "Vec3 Cross failed" );
}
